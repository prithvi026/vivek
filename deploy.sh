#!/bin/bash

###############################################################################
# PhD Research - Automated Deployment Script
# Kubernetes vs Docker Swarm Comparative Study on AWS (ap-south-1)
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Project variables
PROJECT_ROOT=$(pwd)
AWS_REGION="ap-south-1"
CLUSTER_NAME="phd-k8s-cluster"
SSH_KEY_PATH="$HOME/.ssh/id_rsa"

###############################################################################
# Step 1: Pre-flight checks
###############################################################################
preflight_checks() {
    log_info "Running pre-flight checks..."

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi

    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install it first."
        exit 1
    fi

    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install it first."
        exit 1
    fi

    # Check if Helm is installed
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed. Please install it first."
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Run 'aws configure' first."
        exit 1
    fi

    # Check if SSH key exists
    if [ ! -f "$SSH_KEY_PATH" ]; then
        log_warning "SSH key not found at $SSH_KEY_PATH"
        log_info "Generating new SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "phd-research@aws"
        log_success "SSH key generated successfully"
    fi

    log_success "All pre-flight checks passed!"
}

###############################################################################
# Step 2: Deploy AWS infrastructure with Terraform
###############################################################################
deploy_infrastructure() {
    log_info "Deploying AWS infrastructure in region: $AWS_REGION..."

    cd "$PROJECT_ROOT/aws-infrastructure"

    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init

    # Validate configuration
    log_info "Validating Terraform configuration..."
    terraform validate

    # Create execution plan
    log_info "Creating Terraform execution plan..."
    terraform plan -out=tfplan

    # Apply infrastructure
    log_info "Applying infrastructure changes..."
    log_warning "This will provision EC2 instances and incur AWS charges."
    read -p "Continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_warning "Deployment cancelled by user."
        exit 0
    fi

    terraform apply tfplan

    # Save outputs to file
    terraform output -json > outputs.json

    log_success "Infrastructure deployed successfully!"

    cd "$PROJECT_ROOT"
}

###############################################################################
# Step 3: Wait for instances to be ready
###############################################################################
wait_for_instances() {
    log_info "Waiting for EC2 instances to be ready..."

    cd "$PROJECT_ROOT/aws-infrastructure"

    # Get instance IDs
    K8S_CONTROL_PLANE_ID=$(terraform output -raw k8s_control_plane_id)
    K8S_WORKER_1_ID=$(terraform output -raw k8s_worker_1_id)
    K8S_WORKER_2_ID=$(terraform output -raw k8s_worker_2_id)
    DOCKER_MANAGER_ID=$(terraform output -raw docker_manager_id)
    DOCKER_WORKER_1_ID=$(terraform output -raw docker_worker_1_id)
    DOCKER_WORKER_2_ID=$(terraform output -raw docker_worker_2_id)

    # Wait for instances to be running
    log_info "Waiting for Kubernetes control plane..."
    aws ec2 wait instance-running --instance-ids "$K8S_CONTROL_PLANE_ID" --region "$AWS_REGION"

    log_info "Waiting for Kubernetes workers..."
    aws ec2 wait instance-running --instance-ids "$K8S_WORKER_1_ID" "$K8S_WORKER_2_ID" --region "$AWS_REGION"

    log_info "Waiting for Docker Swarm manager..."
    aws ec2 wait instance-running --instance-ids "$DOCKER_MANAGER_ID" --region "$AWS_REGION"

    log_info "Waiting for Docker Swarm workers..."
    aws ec2 wait instance-running --instance-ids "$DOCKER_WORKER_1_ID" "$DOCKER_WORKER_2_ID" --region "$AWS_REGION"

    log_success "All instances are running!"

    # Wait additional time for user_data scripts to complete
    log_info "Waiting 3 minutes for instance initialization..."
    sleep 180

    cd "$PROJECT_ROOT"
}

###############################################################################
# Step 4: Configure Kubernetes cluster
###############################################################################
configure_kubernetes() {
    log_info "Configuring Kubernetes cluster..."

    cd "$PROJECT_ROOT/aws-infrastructure"

    # Get control plane IP
    K8S_CONTROL_IP=$(terraform output -raw k8s_control_plane_public_ip)

    log_info "Kubernetes control plane IP: $K8S_CONTROL_IP"

    # Copy kubeconfig from control plane
    log_info "Retrieving kubeconfig..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" ubuntu@"$K8S_CONTROL_IP" \
        "sudo cat /etc/kubernetes/admin.conf" > "$HOME/.kube/phd-config"

    # Update kubeconfig with public IP
    sed -i "s/127.0.0.1/$K8S_CONTROL_IP/g" "$HOME/.kube/phd-config"

    # Set KUBECONFIG environment variable
    export KUBECONFIG="$HOME/.kube/phd-config"

    # Test connection
    log_info "Testing Kubernetes connection..."
    kubectl get nodes

    log_success "Kubernetes cluster configured!"

    cd "$PROJECT_ROOT"
}

###############################################################################
# Step 5: Install Karpenter
###############################################################################
install_karpenter() {
    log_info "Installing Karpenter..."

    export KUBECONFIG="$HOME/.kube/phd-config"

    # Install Metrics Server first
    log_info "Installing Metrics Server..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    # Wait for Metrics Server to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system

    # Add Karpenter Helm repository
    log_info "Adding Karpenter Helm repository..."
    helm repo add karpenter https://charts.karpenter.sh/
    helm repo update

    # Install Karpenter
    log_info "Deploying Karpenter controller..."
    helm upgrade --install karpenter karpenter/karpenter \
        --namespace kube-system \
        --version v0.33.0 \
        --set settings.aws.clusterName="$CLUSTER_NAME" \
        --set settings.aws.defaultInstanceProfile=KarpenterControllerIAMInstanceProfile \
        --set controller.resources.limits.memory=256Mi \
        --wait

    log_success "Karpenter installed successfully!"
}

###############################################################################
# Step 6: Deploy Kubernetes applications
###############################################################################
deploy_kubernetes_apps() {
    log_info "Deploying Kubernetes applications..."

    export KUBECONFIG="$HOME/.kube/phd-config"

    # Apply EC2NodeClass (create if doesn't exist)
    log_info "Creating EC2NodeClass..."
    cat <<EOF | kubectl apply -f -
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: memory-nodeclass
spec:
  amiFamily: Ubuntu
  role: KarpenterControllerIAMRole
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "$CLUSTER_NAME"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "$CLUSTER_NAME"
EOF

    # Apply NodePool
    log_info "Applying Karpenter NodePool..."
    kubectl apply -f "$PROJECT_ROOT/kubernetes/karpenter-nodepool.yaml"

    # Deploy application
    log_info "Deploying CPU stress application..."
    kubectl apply -f "$PROJECT_ROOT/kubernetes/cpu-stress-deployment-karpenter.yaml"

    # Deploy HPA
    log_info "Deploying Horizontal Pod Autoscaler..."
    kubectl apply -f "$PROJECT_ROOT/kubernetes/hpa-v2.yaml"

    # Wait for pods to be ready
    log_info "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=cpu-stress-app --timeout=300s

    log_success "Kubernetes applications deployed!"
}

###############################################################################
# Step 7: Configure Docker Swarm
###############################################################################
configure_docker_swarm() {
    log_info "Configuring Docker Swarm..."

    cd "$PROJECT_ROOT/aws-infrastructure"

    # Get Docker manager IP
    DOCKER_MANAGER_IP=$(terraform output -raw docker_manager_public_ip)
    DOCKER_WORKER_1_IP=$(terraform output -raw docker_worker_1_public_ip)
    DOCKER_WORKER_2_IP=$(terraform output -raw docker_worker_2_public_ip)

    log_info "Docker Swarm manager IP: $DOCKER_MANAGER_IP"

    # Initialize Docker Swarm on manager
    log_info "Initializing Docker Swarm..."
    ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" ubuntu@"$DOCKER_MANAGER_IP" \
        "docker swarm init"

    # Get join token
    WORKER_TOKEN=$(ssh -i "$SSH_KEY_PATH" ubuntu@"$DOCKER_MANAGER_IP" \
        "docker swarm join-token worker -q")

    MANAGER_PRIVATE_IP=$(ssh -i "$SSH_KEY_PATH" ubuntu@"$DOCKER_MANAGER_IP" \
        "hostname -I | awk '{print \$1}'")

    # Join workers to swarm
    log_info "Joining workers to swarm..."
    ssh -i "$SSH_KEY_PATH" ubuntu@"$DOCKER_WORKER_1_IP" \
        "docker swarm join --token $WORKER_TOKEN $MANAGER_PRIVATE_IP:2377"

    ssh -i "$SSH_KEY_PATH" ubuntu@"$DOCKER_WORKER_2_IP" \
        "docker swarm join --token $WORKER_TOKEN $MANAGER_PRIVATE_IP:2377"

    # Verify swarm
    log_info "Verifying Docker Swarm cluster..."
    ssh -i "$SSH_KEY_PATH" ubuntu@"$DOCKER_MANAGER_IP" "docker node ls"

    log_success "Docker Swarm configured!"

    # Save IPs to environment file
    cat > "$PROJECT_ROOT/.env" <<EOF
DOCKER_MANAGER_IP=$DOCKER_MANAGER_IP
DOCKER_WORKER_1_IP=$DOCKER_WORKER_1_IP
DOCKER_WORKER_2_IP=$DOCKER_WORKER_2_IP
K8S_CONTROL_IP=$K8S_CONTROL_IP
AWS_REGION=$AWS_REGION
EOF

    cd "$PROJECT_ROOT"
}

###############################################################################
# Step 8: Display deployment summary
###############################################################################
display_summary() {
    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "  PhD Research Environment - Deployment Complete!"
    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cd "$PROJECT_ROOT/aws-infrastructure"

    log_info "Kubernetes Cluster:"
    echo "  Control Plane: $(terraform output -raw k8s_control_plane_public_ip)"
    echo "  Worker 1:      $(terraform output -raw k8s_worker_1_public_ip)"
    echo "  Worker 2:      $(terraform output -raw k8s_worker_2_public_ip)"
    echo ""

    log_info "Docker Swarm Cluster:"
    echo "  Manager:       $(terraform output -raw docker_manager_public_ip)"
    echo "  Worker 1:      $(terraform output -raw docker_worker_1_public_ip)"
    echo "  Worker 2:      $(terraform output -raw docker_worker_2_public_ip)"
    echo ""

    log_info "Next Steps:"
    echo "  1. Run experiments:     ./scripts/run_all_tests.sh"
    echo "  2. Monitor comparison:  ./monitoring/monitor_comparison.sh"
    echo "  3. Analyze results:     python3 analysis/analyse_results.py"
    echo ""

    log_info "Environment Configuration:"
    echo "  Region:         $AWS_REGION"
    echo "  Cluster Name:   $CLUSTER_NAME"
    echo "  SSH Key:        $SSH_KEY_PATH"
    echo "  Kubeconfig:     $HOME/.kube/phd-config"
    echo ""

    log_warning "Important:"
    echo "  - Set environment: source .env"
    echo "  - Set kubeconfig:  export KUBECONFIG=\$HOME/.kube/phd-config"
    echo "  - Remember to destroy resources when done: cd aws-infrastructure && terraform destroy"
    echo ""

    cd "$PROJECT_ROOT"
}

###############################################################################
# Main execution flow
###############################################################################
main() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  PhD Research - Automated AWS Deployment"
    echo "  Kubernetes vs Docker Swarm Comparative Study"
    echo "  Region: ap-south-1 (Mumbai)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Confirm deployment
    log_warning "This script will deploy the following resources in AWS:"
    echo "  - 1 VPC with public/private subnets"
    echo "  - 1 NAT Gateway"
    echo "  - 3 EC2 instances for Kubernetes (1x t3.medium, 2x t2.micro)"
    echo "  - 3 EC2 instances for Docker Swarm (3x t2.micro)"
    echo "  - Security groups, IAM roles, and networking"
    echo ""
    log_warning "Estimated cost: ~\$2-3 per day"
    echo ""

    read -p "Do you want to proceed with deployment? (yes/no): " proceed

    if [ "$proceed" != "yes" ]; then
        log_warning "Deployment cancelled by user."
        exit 0
    fi

    echo ""

    # Execute deployment steps
    preflight_checks
    deploy_infrastructure
    wait_for_instances
    configure_kubernetes
    install_karpenter
    deploy_kubernetes_apps
    configure_docker_swarm
    display_summary

    log_success "Deployment completed successfully!"
}

# Run main function
main
