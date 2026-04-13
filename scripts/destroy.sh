#!/bin/bash

###############################################################################
# PhD Research - Cleanup and Destroy Script
# Safely destroys all AWS resources created for the research
###############################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
AWS_REGION="ap-south-1"

###############################################################################
# Warning and confirmation
###############################################################################
show_warning() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ⚠️  RESOURCE DESTRUCTION WARNING"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_warning "This script will PERMANENTLY DELETE the following resources:"
    echo ""
    echo "  🗑️  6 EC2 instances (Kubernetes + Docker Swarm)"
    echo "  🗑️  1 VPC with all subnets"
    echo "  🗑️  1 NAT Gateway"
    echo "  🗑️  1 Internet Gateway"
    echo "  🗑️  Security Groups"
    echo "  🗑️  IAM Roles and Policies"
    echo "  🗑️  EBS Volumes"
    echo "  🗑️  Elastic IPs"
    echo ""
    log_error "THIS ACTION CANNOT BE UNDONE!"
    echo ""
    log_warning "All research data on the instances will be lost."
    log_warning "Make sure you have backed up any results before proceeding."
    echo ""
}

###############################################################################
# Check if infrastructure exists
###############################################################################
check_infrastructure() {
    log_info "Checking if infrastructure exists..."

    cd "$PROJECT_ROOT/aws-infrastructure"

    if [ ! -f "terraform.tfstate" ]; then
        log_warning "No Terraform state found. Nothing to destroy."
        exit 0
    fi

    # Check if any resources exist
    resource_count=$(terraform state list 2>/dev/null | wc -l)

    if [ "$resource_count" -eq 0 ]; then
        log_warning "No resources found in Terraform state."
        exit 0
    fi

    log_info "Found $resource_count resources to destroy."

    cd "$PROJECT_ROOT"
}

###############################################################################
# Backup results data
###############################################################################
backup_results() {
    log_info "Checking for experimental results..."

    if [ -d "$PROJECT_ROOT/results" ]; then
        BACKUP_DIR="$PROJECT_ROOT/results_backup_$(date +%Y%m%d_%H%M%S)"
        log_info "Backing up results to: $BACKUP_DIR"
        cp -r "$PROJECT_ROOT/results" "$BACKUP_DIR"
        log_success "Results backed up successfully!"
    else
        log_info "No results directory found. Skipping backup."
    fi
}

###############################################################################
# Save infrastructure outputs
###############################################################################
save_outputs() {
    log_info "Saving infrastructure outputs before destruction..."

    cd "$PROJECT_ROOT/aws-infrastructure"

    if terraform output &> /dev/null; then
        terraform output -json > "$PROJECT_ROOT/infrastructure_final_state.json"
        log_success "Infrastructure state saved to infrastructure_final_state.json"
    fi

    cd "$PROJECT_ROOT"
}

###############################################################################
# Drain Kubernetes pods
###############################################################################
drain_kubernetes() {
    log_info "Attempting to drain Kubernetes resources..."

    if [ -f "$HOME/.kube/phd-config" ]; then
        export KUBECONFIG="$HOME/.kube/phd-config"

        if kubectl cluster-info &> /dev/null; then
            log_info "Deleting application deployments..."
            kubectl delete deployment cpu-stress-app --ignore-not-found=true || true
            kubectl delete hpa cpu-stress-hpa --ignore-not-found=true || true
            kubectl delete nodepool memory-optimised-pool --ignore-not-found=true || true

            log_info "Waiting for resources to terminate..."
            sleep 10

            log_success "Kubernetes resources drained."
        else
            log_warning "Cannot connect to Kubernetes cluster. Skipping drain."
        fi
    else
        log_warning "Kubeconfig not found. Skipping Kubernetes drain."
    fi
}

###############################################################################
# Destroy infrastructure with Terraform
###############################################################################
destroy_infrastructure() {
    log_info "Destroying AWS infrastructure..."

    cd "$PROJECT_ROOT/aws-infrastructure"

    # Run terraform destroy
    log_warning "Starting Terraform destroy process..."
    terraform destroy -auto-approve

    log_success "Infrastructure destroyed successfully!"

    cd "$PROJECT_ROOT"
}

###############################################################################
# Verify cleanup
###############################################################################
verify_cleanup() {
    log_info "Verifying resource cleanup..."

    # Check for remaining instances
    instances=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:Project,Values=k8s-docker-comparison" \
                  "Name=instance-state-name,Values=running,pending,stopping,stopped" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text 2>/dev/null || echo "")

    if [ -z "$instances" ]; then
        log_success "✅ No EC2 instances found"
    else
        log_warning "⚠️  Some instances still exist: $instances"
    fi

    # Check for VPCs
    vpcs=$(aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters "Name=tag:Project,Values=k8s-docker-comparison" \
        --query "Vpcs[].VpcId" \
        --output text 2>/dev/null || echo "")

    if [ -z "$vpcs" ]; then
        log_success "✅ No VPCs found"
    else
        log_warning "⚠️  Some VPCs still exist: $vpcs"
    fi

    # Check for NAT Gateways
    nat_gws=$(aws ec2 describe-nat-gateways \
        --region "$AWS_REGION" \
        --filter "Name=tag:Project,Values=k8s-docker-comparison" \
        --query "NatGateways[?State!='deleted'].NatGatewayId" \
        --output text 2>/dev/null || echo "")

    if [ -z "$nat_gws" ]; then
        log_success "✅ No NAT Gateways found"
    else
        log_warning "⚠️  Some NAT Gateways still exist: $nat_gws"
        log_info "NAT Gateways may take a few minutes to fully delete."
    fi
}

###############################################################################
# Clean up local files
###############################################################################
cleanup_local() {
    log_info "Cleaning up local configuration files..."

    # Remove kubeconfig
    if [ -f "$HOME/.kube/phd-config" ]; then
        rm -f "$HOME/.kube/phd-config"
        log_success "Removed kubeconfig file"
    fi

    # Remove .env file
    if [ -f "$PROJECT_ROOT/.env" ]; then
        rm -f "$PROJECT_ROOT/.env"
        log_success "Removed .env file"
    fi

    # Remove Terraform state backups (optional)
    read -p "Remove Terraform state and backup files? (yes/no): " remove_state
    if [ "$remove_state" == "yes" ]; then
        cd "$PROJECT_ROOT/aws-infrastructure"
        rm -f terraform.tfstate*
        rm -f outputs.json
        rm -f tfplan
        log_success "Removed Terraform state files"
        cd "$PROJECT_ROOT"
    fi
}

###############################################################################
# Display summary
###############################################################################
display_summary() {
    echo ""
    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "  Cleanup Complete!"
    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Summary:"
    echo "  ✅ AWS infrastructure destroyed"
    echo "  ✅ Local configuration files cleaned"
    echo "  ✅ Resources verified"
    echo ""

    if [ -d "$PROJECT_ROOT/results_backup_"* 2>/dev/null ]; then
        log_info "Your results have been backed up to:"
        ls -d "$PROJECT_ROOT"/results_backup_* 2>/dev/null || true
        echo ""
    fi

    log_info "Next steps:"
    echo "  - Verify charges in AWS Console"
    echo "  - Check for any remaining resources"
    echo "  - Review backed up results"
    echo ""
    log_warning "Note: NAT Gateway deletion may take 5-10 minutes to complete"
    echo ""
}

###############################################################################
# Main execution
###############################################################################
main() {
    show_warning

    # Confirmation prompt
    read -p "Type 'DESTROY' to confirm resource deletion: " confirmation

    if [ "$confirmation" != "DESTROY" ]; then
        log_warning "Destruction cancelled. No resources were deleted."
        exit 0
    fi

    echo ""

    # Execute cleanup steps
    check_infrastructure
    backup_results
    save_outputs
    drain_kubernetes
    destroy_infrastructure
    verify_cleanup
    cleanup_local
    display_summary

    log_success "All cleanup operations completed successfully!"
}

# Run main function
main
