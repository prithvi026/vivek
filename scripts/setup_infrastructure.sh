#!/bin/bash
"""
Infrastructure Setup Script for PhD Research
Kubernetes vs Docker Swarm on AWS

This script automates the complete infrastructure provisioning using Terraform
and configures both Kubernetes and Docker Swarm clusters for the research study.
"""

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AWS_REGION="${AWS_REGION:-us-west-2}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Helper functions
log_section() {
    echo ""
    echo -e "${MAGENTA}================================================================${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${MAGENTA}================================================================${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Pre-flight checks
run_preflight_checks() {
    log_section "INFRASTRUCTURE PRE-FLIGHT CHECKS"
    
    local checks_passed=true
    
    # Check required tools
    log_info "Checking required tools..."
    
    local required_tools=("terraform" "aws" "ssh-keygen")
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_info "✓ $tool found"
        else
            log_error "✗ $tool not found"
            checks_passed=false
        fi
    done
    
    # Check AWS credentials
    log_info "Checking AWS credentials..."
    if aws sts get-caller-identity >/dev/null 2>&1; then
        local aws_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
        local aws_user=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "unknown")
        log_info "✓ AWS credentials configured (Account: $aws_account)"
        log_info "  User/Role: $aws_user"
    else
        log_error "✗ AWS credentials not configured"
        log_error "  Please run: aws configure"
        checks_passed=false
    fi
    
    # Check SSH key
    log_info "Checking SSH key pair..."
    if [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
        log_warn "SSH key pair not found, generating new one..."
        ssh-keygen -t rsa -b 2048 -f "$HOME/.ssh/id_rsa" -N "" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_info "✓ SSH key pair generated"
        else
            log_error "✗ Failed to generate SSH key pair"
            checks_passed=false
        fi
    else
        log_info "✓ SSH key pair exists"
    fi
    
    if [ "$checks_passed" = true ]; then
        log_success "All pre-flight checks passed"
        return 0
    else
        log_error "Pre-flight checks failed"
        return 1
    fi
}

# Initialize Terraform
init_terraform() {
    log_section "INITIALIZING TERRAFORM"
    
    cd "$PROJECT_ROOT/aws-infrastructure"
    
    log_info "Initializing Terraform..."
    if terraform init; then
        log_success "Terraform initialized successfully"
    else
        log_error "Failed to initialize Terraform"
        return 1
    fi
    
    log_info "Validating Terraform configuration..."
    if terraform validate; then
        log_success "Terraform configuration is valid"
    else
        log_error "Terraform configuration validation failed"
        return 1
    fi
    
    return 0
}

# Plan and apply infrastructure
deploy_infrastructure() {
    log_section "DEPLOYING AWS INFRASTRUCTURE"
    
    cd "$PROJECT_ROOT/aws-infrastructure"
    
    # Create terraform.tfvars if it doesn't exist
    if [ ! -f terraform.tfvars ]; then
        log_info "Creating terraform.tfvars..."
        cat > terraform.tfvars << EOF
aws_region = "$AWS_REGION"
cluster_name = "phd-k8s-cluster"
environment = "research"
project_name = "k8s-docker-comparison"
EOF
    fi
    
    log_info "Planning infrastructure deployment..."
    if terraform plan -out=tfplan; then
        log_success "Terraform plan completed"
    else
        log_error "Terraform planning failed"
        return 1
    fi
    
    log_info "Applying infrastructure changes..."
    if terraform apply -auto-approve tfplan; then
        log_success "Infrastructure deployed successfully"
    else
        log_error "Infrastructure deployment failed"
        return 1
    fi
    
    # Save outputs for later use
    terraform output -json > "$PROJECT_ROOT/terraform_outputs.json"
    log_info "Terraform outputs saved to terraform_outputs.json"
    
    return 0
}

# Extract infrastructure information
extract_infrastructure_info() {
    log_section "EXTRACTING INFRASTRUCTURE INFORMATION"
    
    if [ ! -f "$PROJECT_ROOT/terraform_outputs.json" ]; then
        log_error "Terraform outputs not found"
        return 1
    fi
    
    # Extract key information
    local k8s_control_plane_ip=$(cat "$PROJECT_ROOT/terraform_outputs.json" | jq -r '.k8s_control_plane_public_ip.value // empty')
    local k8s_worker_ips=$(cat "$PROJECT_ROOT/terraform_outputs.json" | jq -r '.k8s_worker_public_ips.value[]? // empty')
    local docker_manager_ip=$(cat "$PROJECT_ROOT/terraform_outputs.json" | jq -r '.docker_manager_public_ip.value // empty')
    local docker_worker_ips=$(cat "$PROJECT_ROOT/terraform_outputs.json" | jq -r '.docker_worker_public_ips.value[]? // empty')
    
    # Create environment file
    cat > "$PROJECT_ROOT/infrastructure.env" << EOF
# PhD Research Infrastructure Information
# Generated on $(date)

# Kubernetes Cluster
export K8S_CONTROL_PLANE_IP="$k8s_control_plane_ip"
export K8S_WORKER_IPS="$k8s_worker_ips"

# Docker Swarm Cluster
export DOCKER_MANAGER_IP="$docker_manager_ip"
export DOCKER_WORKER_IPS="$docker_worker_ips"

# Individual Docker Workers (for scripts)
EOF
    
    # Add individual Docker worker IPs
    local counter=1
    echo "$docker_worker_ips" | while read -r ip; do
        if [ -n "$ip" ]; then
            echo "export DOCKER_WORKER${counter}=\"$ip\"" >> "$PROJECT_ROOT/infrastructure.env"
            ((counter++))
        fi
    done
    
    log_success "Infrastructure information saved to infrastructure.env"
    log_info "Key IP addresses:"
    log_info "  Kubernetes Control Plane: $k8s_control_plane_ip"
    log_info "  Docker Swarm Manager: $docker_manager_ip"
    
    return 0
}

# Configure Kubernetes cluster
configure_kubernetes() {
    log_section "CONFIGURING KUBERNETES CLUSTER"
    
    source "$PROJECT_ROOT/infrastructure.env"
    
    if [ -z "$K8S_CONTROL_PLANE_IP" ]; then
        log_error "Kubernetes control plane IP not found"
        return 1
    fi
    
    log_info "Waiting for Kubernetes control plane to be ready..."
    local retries=0
    local max_retries=30
    
    while [ $retries -lt $max_retries ]; do
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$K8S_CONTROL_PLANE_IP "kubectl get nodes" >/dev/null 2>&1; then
            log_success "Kubernetes control plane is accessible"
            break
        fi
        
        log_info "Waiting for control plane... ($((retries + 1))/$max_retries)"
        sleep 30
        ((retries++))
    done
    
    if [ $retries -eq $max_retries ]; then
        log_error "Kubernetes control plane not accessible after timeout"
        return 1
    fi
    
    # Copy kubeconfig
    log_info "Copying kubeconfig..."
    if scp -o StrictHostKeyChecking=no ubuntu@$K8S_CONTROL_PLANE_IP:~/.kube/config ~/.kube/config; then
        log_success "Kubeconfig copied successfully"
        
        # Update kubeconfig server URL
        sed -i.bak "s/https:\/\/[0-9.]*:6443/https:\/\/$K8S_CONTROL_PLANE_IP:6443/g" ~/.kube/config
        log_info "Kubeconfig updated with public IP"
    else
        log_error "Failed to copy kubeconfig"
        return 1
    fi
    
    # Join worker nodes
    log_info "Joining worker nodes to cluster..."
    local join_command
    join_command=$(ssh -o StrictHostKeyChecking=no ubuntu@$K8S_CONTROL_PLANE_IP "cat ~/k8s-join-command.sh")
    
    echo "$K8S_WORKER_IPS" | while read -r worker_ip; do
        if [ -n "$worker_ip" ]; then
            log_info "Joining worker node $worker_ip..."
            if ssh -o StrictHostKeyChecking=no ubuntu@$worker_ip "sudo $join_command" >/dev/null 2>&1; then
                log_info "✓ Worker $worker_ip joined successfully"
            else
                log_warn "✗ Failed to join worker $worker_ip"
            fi
        fi
    done
    
    # Wait for nodes to be ready
    log_info "Waiting for all nodes to be ready..."
    sleep 60
    
    local ready_nodes=$(kubectl get nodes --no-headers | grep -c Ready || echo "0")
    log_info "Ready nodes: $ready_nodes"
    
    if [ "$ready_nodes" -ge 2 ]; then
        log_success "Kubernetes cluster is ready"
        return 0
    else
        log_warn "Some nodes may not be ready yet"
        return 0
    fi
}

# Install Karpenter
install_karpenter() {
    log_section "INSTALLING KARPENTER"
    
    log_info "Installing Metrics Server (required for HPA)..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml >/dev/null 2>&1 || log_warn "Metrics Server installation may have failed"
    
    log_info "Adding Karpenter Helm repository..."
    if command -v helm >/dev/null 2>&1; then
        helm repo add karpenter https://charts.karpenter.sh/ >/dev/null 2>&1
        helm repo update >/dev/null 2>&1
        
        log_info "Installing Karpenter..."
        # Note: This is a simplified installation. In production, you'd need proper IAM roles and permissions
        if helm upgrade --install karpenter karpenter/karpenter \
            --namespace kube-system \
            --version v0.33.0 \
            --set settings.aws.clusterName=phd-k8s-cluster \
            --set controller.resources.limits.memory=256Mi \
            --wait --timeout=300s >/dev/null 2>&1; then
            log_success "Karpenter installed successfully"
        else
            log_warn "Karpenter installation may have failed (continuing without it)"
        fi
    else
        log_warn "Helm not found, skipping Karpenter installation"
    fi
    
    return 0
}

# Configure Docker Swarm
configure_docker_swarm() {
    log_section "CONFIGURING DOCKER SWARM"
    
    source "$PROJECT_ROOT/infrastructure.env"
    
    if [ -z "$DOCKER_MANAGER_IP" ]; then
        log_error "Docker manager IP not found"
        return 1
    fi
    
    log_info "Waiting for Docker Swarm manager to be ready..."
    local retries=0
    local max_retries=20
    
    while [ $retries -lt $max_retries ]; do
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$DOCKER_MANAGER_IP "docker node ls" >/dev/null 2>&1; then
            log_success "Docker Swarm manager is accessible"
            break
        fi
        
        log_info "Waiting for Docker Swarm... ($((retries + 1))/$max_retries)"
        sleep 20
        ((retries++))
    done
    
    if [ $retries -eq $max_retries ]; then
        log_error "Docker Swarm manager not accessible after timeout"
        return 1
    fi
    
    # Get join command and join workers
    log_info "Joining worker nodes to Docker Swarm..."
    local join_command
    join_command=$(ssh -o StrictHostKeyChecking=no ubuntu@$DOCKER_MANAGER_IP "cat ~/swarm-join-command.sh" 2>/dev/null || echo "")
    
    if [ -n "$join_command" ]; then
        echo "$DOCKER_WORKER_IPS" | while read -r worker_ip; do
            if [ -n "$worker_ip" ]; then
                log_info "Joining Docker worker $worker_ip..."
                if ssh -o StrictHostKeyChecking=no ubuntu@$worker_ip "$join_command" >/dev/null 2>&1; then
                    log_info "✓ Worker $worker_ip joined successfully"
                else
                    log_warn "✗ Failed to join worker $worker_ip"
                fi
            fi
        done
    else
        log_warn "Could not get Docker Swarm join command"
    fi
    
    # Verify cluster
    local swarm_nodes=$(ssh -o StrictHostKeyChecking=no ubuntu@$DOCKER_MANAGER_IP "docker node ls --format '{{.Hostname}}'" 2>/dev/null | wc -l || echo "0")
    log_info "Docker Swarm nodes: $swarm_nodes"
    
    if [ "$swarm_nodes" -ge 2 ]; then
        log_success "Docker Swarm cluster is ready"
    else
        log_warn "Docker Swarm cluster may not be fully ready"
    fi
    
    return 0
}

# Generate connection instructions
generate_connection_instructions() {
    log_section "GENERATING CONNECTION INSTRUCTIONS"
    
    source "$PROJECT_ROOT/infrastructure.env"
    
    cat > "$PROJECT_ROOT/CONNECTION_INSTRUCTIONS.md" << EOF
# PhD Research Infrastructure Connection Guide

## 🚀 Quick Start

### Load Environment Variables
\`\`\`bash
source ./infrastructure.env
\`\`\`

### Run Complete Research Study
\`\`\`bash
./scripts/run_all_tests.sh --docker-manager \$DOCKER_MANAGER_IP --docker-worker1 \$DOCKER_WORKER1 --docker-worker2 \$DOCKER_WORKER2
\`\`\`

## 🔑 SSH Connections

### Kubernetes Control Plane
\`\`\`bash
ssh ubuntu@$K8S_CONTROL_PLANE_IP
\`\`\`

### Docker Swarm Manager  
\`\`\`bash
ssh ubuntu@$DOCKER_MANAGER_IP
\`\`\`

### Worker Nodes
EOF

    local counter=1
    echo "$K8S_WORKER_IPS" | while read -r ip; do
        if [ -n "$ip" ]; then
            echo "- Kubernetes Worker $counter: \`ssh ubuntu@$ip\`" >> "$PROJECT_ROOT/CONNECTION_INSTRUCTIONS.md"
            ((counter++))
        fi
    done
    
    counter=1
    echo "$DOCKER_WORKER_IPS" | while read -r ip; do
        if [ -n "$ip" ]; then
            echo "- Docker Worker $counter: \`ssh ubuntu@$ip\`" >> "$PROJECT_ROOT/CONNECTION_INSTRUCTIONS.md"
            ((counter++))
        fi
    done

    cat >> "$PROJECT_ROOT/CONNECTION_INSTRUCTIONS.md" << EOF

## ⚙️ Service Access

### Kubernetes Applications
- **CPU Stress Service**: http://$K8S_CONTROL_PLANE_IP:30080
- **Health Check**: http://$K8S_CONTROL_PLANE_IP:30080/health
- **Metrics**: http://$K8S_CONTROL_PLANE_IP:30080/metrics

### Docker Swarm Applications
EOF

    echo "$DOCKER_WORKER_IPS" | head -1 | while read -r ip; do
        if [ -n "$ip" ]; then
            cat >> "$PROJECT_ROOT/CONNECTION_INSTRUCTIONS.md" << EOF
- **CPU Stress Service**: http://$ip:8081
- **Health Check**: http://$ip:8081/health  
- **Metrics**: http://$ip:8081/metrics
EOF
        fi
    done

    cat >> "$PROJECT_ROOT/CONNECTION_INSTRUCTIONS.md" << EOF

## 🧪 Research Commands

### Individual Test Scenarios
\`\`\`bash
# Normal load scenario (30 minutes)
./monitoring/monitor_comparison.sh --scenario normal_load --duration 1800

# High load scenario (20 minutes)  
./monitoring/monitor_comparison.sh --scenario high_load --duration 1200

# Variable load scenario (45 minutes)
./monitoring/monitor_comparison.sh --scenario variable_load --duration 2700

# Fault tolerance test
./scripts/fault_tolerance_test.sh --platform both
\`\`\`

### Analysis
\`\`\`bash
# Run statistical analysis
python3 analysis/analyse_results.py ./results/obj3_results_TIMESTAMP --generate-plots

# View research report
cat ./results/complete_study_TIMESTAMP/FINAL_RESEARCH_REPORT.md
\`\`\`

## 🛠️ Troubleshooting

### Restart Services
\`\`\`bash
# Restart Kubernetes pods
kubectl delete pods -l app=cpu-stress
kubectl get pods -w

# Restart Docker Swarm services  
ssh ubuntu@$DOCKER_MANAGER_IP "docker service update --force phd-research_cpu-stress-app"
\`\`\`

### Check Cluster Status
\`\`\`bash
# Kubernetes
kubectl get nodes -o wide
kubectl get pods -A

# Docker Swarm
ssh ubuntu@$DOCKER_MANAGER_IP "docker node ls"
ssh ubuntu@$DOCKER_MANAGER_IP "docker service ls"
\`\`\`

## 🧹 Cleanup
\`\`\`bash
# Destroy infrastructure when done
cd aws-infrastructure
terraform destroy -auto-approve
\`\`\`

---
**Generated on:** $(date)  
**AWS Region:** $AWS_REGION  
**Study Status:** ✅ Ready for execution
EOF

    log_success "Connection instructions generated: CONNECTION_INSTRUCTIONS.md"
}

# Cleanup function
cleanup() {
    log_info "Cleanup function called"
    cd "$PROJECT_ROOT"
}

# Main execution function
main() {
    log_section "PhD RESEARCH INFRASTRUCTURE SETUP"
    log_info "Kubernetes vs Docker Swarm on AWS"
    
    # Parse command line arguments
    local skip_deploy=false
    local skip_configure=false
    local destroy=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-deploy)
                skip_deploy=true
                shift
                ;;
            --skip-configure)  
                skip_configure=true
                shift
                ;;
            --destroy)
                destroy=true
                shift
                ;;
            --region)
                AWS_REGION="$2"
                shift 2
                ;;
            --help)
                cat << 'EOF'
PhD Research Infrastructure Setup

Usage: ./setup_infrastructure.sh [OPTIONS]

Options:
  --skip-deploy         Skip Terraform infrastructure deployment
  --skip-configure      Skip cluster configuration
  --destroy            Destroy existing infrastructure
  --region REGION      AWS region (default: us-west-2)
  --help               Show this help message

Examples:
  # Complete setup
  ./setup_infrastructure.sh
  
  # Setup in different region
  ./setup_infrastructure.sh --region us-east-1
  
  # Destroy infrastructure
  ./setup_infrastructure.sh --destroy

EOF
                exit 0
                ;;
            *)
                log_error "Unknown parameter: $1"
                exit 1
                ;;
        esac
    done
    
    # Handle destroy request
    if [ "$destroy" = true ]; then
        log_section "DESTROYING INFRASTRUCTURE"
        cd "$PROJECT_ROOT/aws-infrastructure"
        
        if terraform destroy -auto-approve; then
            log_success "Infrastructure destroyed successfully"
            rm -f "$PROJECT_ROOT/terraform_outputs.json"
            rm -f "$PROJECT_ROOT/infrastructure.env"
            rm -f "$PROJECT_ROOT/CONNECTION_INSTRUCTIONS.md"
        else
            log_error "Failed to destroy infrastructure"
            exit 1
        fi
        return 0
    fi
    
    # Setup signal handlers
    trap cleanup EXIT INT TERM
    
    # Run setup sequence
    run_preflight_checks
    
    if [ "$skip_deploy" = false ]; then
        init_terraform
        deploy_infrastructure
        extract_infrastructure_info
    fi
    
    if [ "$skip_configure" = false ]; then
        configure_kubernetes
        install_karpenter
        configure_docker_swarm
    fi
    
    generate_connection_instructions
    
    # Final summary
    log_section "INFRASTRUCTURE SETUP COMPLETE"
    log_success "PhD Research infrastructure is ready!"
    log_info "Next steps:"
    log_info "  1. Review CONNECTION_INSTRUCTIONS.md for access details"
    log_info "  2. Source the environment: source ./infrastructure.env"
    log_info "  3. Run the complete study: ./scripts/run_all_tests.sh"
    log_info ""
    log_info "Infrastructure components:"
    log_info "  ✅ Kubernetes cluster with Karpenter"
    log_info "  ✅ Docker Swarm cluster" 
    log_info "  ✅ Monitoring and analysis tools"
    log_info "  ✅ PhD research framework"
    
    echo ""
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi