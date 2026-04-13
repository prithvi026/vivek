# PhD Research Deployment Guide
## Kubernetes vs Docker Swarm on AWS (ap-south-1)

This guide will help you deploy the complete PhD research infrastructure for comparing Kubernetes with Karpenter against Docker Swarm on AWS.

---

## 📋 Prerequisites

Before starting, ensure you have the following installed:

### Required Software
- **AWS CLI** (v2.x or later)
- **Terraform** (v1.0 or later)
- **kubectl** (v1.28 or later)
- **Helm** (v3.x or later)
- **Docker** (for local testing)
- **Git**
- **Python 3.8+** with pip
- **Bash** shell (Linux/macOS/WSL)

### AWS Requirements
- Active AWS account
- IAM user with appropriate permissions (EC2, VPC, IAM)
- AWS credentials configured (`aws configure`)
- SSH key pair (will be created automatically if not present)

### Cost Estimate
- **Estimated daily cost**: $2-3 USD
- **Resources**: 6 EC2 instances, 1 NAT Gateway, networking
- **Duration**: Recommended to destroy after experiments

---

## 🚀 Quick Start (Automated Deployment)

### Step 1: Configure AWS Credentials

```bash
aws configure
# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: ap-south-1
# - Output format: json
```

### Step 2: Clone and Navigate to Project

```bash
cd /path/to/B2A
```

### Step 3: Make Deployment Script Executable

```bash
chmod +x deploy.sh
chmod +x scripts/*.sh
chmod +x monitoring/*.sh
```

### Step 4: Run Automated Deployment

```bash
./deploy.sh
```

This single command will:
1. ✅ Run pre-flight checks
2. ✅ Deploy AWS infrastructure (VPC, EC2, networking)
3. ✅ Wait for instances to initialize
4. ✅ Configure Kubernetes cluster
5. ✅ Install Karpenter with Metrics Server
6. ✅ Deploy CPU stress application
7. ✅ Configure Docker Swarm cluster
8. ✅ Display connection information

**Total deployment time**: ~15-20 minutes

---

## 📊 Running Experiments

### Load Environment Variables

```bash
source .env
export KUBECONFIG=$HOME/.kube/phd-config
```

### Run All Four Test Scenarios

```bash
./scripts/run_all_tests.sh
```

This executes:
- **Scenario 1**: Normal load (30-50% CPU, 30 min)
- **Scenario 2**: High load (80-95% CPU, 20 min)
- **Scenario 3**: Variable load (20-90% cycling, 45 min)
- **Scenario 4**: Fault tolerance (node failure + recovery)

### Monitor in Real-Time

```bash
# Kubernetes monitoring
kubectl get pods -w
kubectl top nodes
kubectl get hpa -w

# Docker Swarm monitoring
ssh ubuntu@$DOCKER_MANAGER_IP "docker service ps my-cpu-stressor"
ssh ubuntu@$DOCKER_MANAGER_IP "docker node ls"
```

### Run Comparative Monitoring

```bash
./monitoring/monitor_comparison.sh
```

---

## 📈 Analyzing Results

### Generate Statistical Analysis

```bash
python3 analysis/analyse_results.py ./results/
```

### Expected Outputs

The analysis script generates:
- `memory_waste_comparison.csv` - Primary research metric
- `metric_summary.csv` - Full performance breakdown
- `scaling_events.csv` - Autoscaling activity log
- `charts/` - Visualization graphs

### Key Metrics to Review

1. **Memory Waste Reduction**: Target ~71% improvement
2. **CPU Utilization**: Kubernetes should reach 90-95%
3. **Scaling Speed**: Kubernetes 15-25s vs Docker 30-45s
4. **Fault Recovery**: Kubernetes 30-60s vs Docker 2-3 min

---

## 🔧 Manual Configuration (Alternative)

If you need to configure manually instead of using `deploy.sh`:

### 1. Deploy Infrastructure

```bash
cd aws-infrastructure
terraform init
terraform plan
terraform apply
terraform output -json > outputs.json
```

### 2. Configure Kubernetes

```bash
# Get control plane IP
K8S_IP=$(terraform output -raw k8s_control_plane_public_ip)

# Copy kubeconfig
ssh ubuntu@$K8S_IP "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/phd-config

# Update with public IP
sed -i "s/127.0.0.1/$K8S_IP/g" ~/.kube/phd-config

# Test connection
export KUBECONFIG=~/.kube/phd-config
kubectl get nodes
```

### 3. Install Karpenter

```bash
# Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Karpenter
helm repo add karpenter https://charts.karpenter.sh/
helm repo update
helm upgrade --install karpenter karpenter/karpenter \
  --namespace kube-system \
  --version v0.33.0 \
  --set settings.aws.clusterName=phd-k8s-cluster \
  --set controller.resources.limits.memory=256Mi \
  --wait
```

### 4. Deploy Applications

```bash
kubectl apply -f kubernetes/karpenter-nodepool.yaml
kubectl apply -f kubernetes/cpu-stress-deployment-karpenter.yaml
kubectl apply -f kubernetes/hpa-v2.yaml
```

### 5. Configure Docker Swarm

```bash
# Initialize swarm
DOCKER_IP=$(terraform output -raw docker_manager_public_ip)
ssh ubuntu@$DOCKER_IP "docker swarm init"

# Get join token
TOKEN=$(ssh ubuntu@$DOCKER_IP "docker swarm join-token worker -q")
MANAGER_PRIVATE=$(ssh ubuntu@$DOCKER_IP "hostname -I | awk '{print \$1}'")

# Join workers
WORKER1=$(terraform output -raw docker_worker_1_public_ip)
WORKER2=$(terraform output -raw docker_worker_2_public_ip)

ssh ubuntu@$WORKER1 "docker swarm join --token $TOKEN $MANAGER_PRIVATE:2377"
ssh ubuntu@$WORKER2 "docker swarm join --token $TOKEN $MANAGER_PRIVATE:2377"
```

---

## 🧪 Individual Test Scenarios

### Scenario 1: Normal Load

```bash
# Kubernetes
kubectl exec -it <pod-name> -- curl http://localhost:5000/set_cpu_target?target=40

# Docker Swarm
curl http://$DOCKER_WORKER_1_IP:8081/set_cpu_target?target=40

# Monitor for 30 minutes
```

### Scenario 2: High Load

```bash
# Kubernetes
kubectl exec -it <pod-name> -- curl http://localhost:5000/set_cpu_target?target=90

# Docker Swarm
curl http://$DOCKER_WORKER_1_IP:8081/set_cpu_target?target=90

# Monitor for 20 minutes
```

### Scenario 3: Variable Load

```bash
# Use the automated script
./scripts/variable_load_test.sh
```

### Scenario 4: Fault Tolerance

```bash
./scripts/fault_tolerance_test.sh
```

---

## 🛠️ Troubleshooting

### Common Issues

#### 1. Terraform Apply Fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check region availability
aws ec2 describe-availability-zones --region ap-south-1

# Verify SSH key
ls -la ~/.ssh/id_rsa.pub
```

#### 2. kubectl Connection Fails

```bash
# Verify kubeconfig
export KUBECONFIG=~/.kube/phd-config
kubectl config view

# Test with verbose output
kubectl get nodes -v=6

# Check control plane is accessible
ssh ubuntu@$K8S_IP "sudo systemctl status kubelet"
```

#### 3. Karpenter Not Provisioning Nodes

```bash
# Check Karpenter logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter

# Verify IAM permissions
kubectl get nodepools
kubectl get ec2nodeclasses

# Check pending pods
kubectl get pods --field-selector=status.phase=Pending
```

#### 4. Docker Swarm Worker Join Fails

```bash
# Check swarm status
ssh ubuntu@$DOCKER_IP "docker info | grep Swarm"

# Regenerate token
ssh ubuntu@$DOCKER_IP "docker swarm join-token worker"

# Check ports
ssh ubuntu@$DOCKER_IP "sudo netstat -tlnp | grep 2377"
```

#### 5. Metrics Server Not Working

```bash
# Check metrics-server status
kubectl get pods -n kube-system | grep metrics-server

# Patch for insecure TLS (if needed)
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

---

## 🧹 Cleanup and Destroy

### Quick Destroy

```bash
./scripts/destroy.sh
```

### Manual Destroy

```bash
cd aws-infrastructure

# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm by typing: yes
```

### Verify Cleanup

```bash
# Check no instances remain
aws ec2 describe-instances \
  --region ap-south-1 \
  --filters "Name=tag:Project,Values=k8s-docker-comparison" \
  --query "Reservations[].Instances[].InstanceId"

# Check no VPCs remain
aws ec2 describe-vpcs \
  --region ap-south-1 \
  --filters "Name=tag:Project,Values=k8s-docker-comparison"
```

---

## 📞 Support and Documentation

### Project Structure

```
B2A/
├── deploy.sh                   # Main deployment script
├── DEPLOYMENT_GUIDE.md         # This file
├── README.md                   # Project overview
├── aws-infrastructure/         # Terraform code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── user_data/              # Instance initialization scripts
├── kubernetes/                 # K8s manifests
│   ├── karpenter-nodepool.yaml
│   ├── cpu-stress-deployment-karpenter.yaml
│   └── hpa-v2.yaml
├── docker-swarm/              # Docker compose files
├── applications/              # Flask CPU stress app
├── monitoring/                # Monitoring scripts
├── analysis/                  # Results analysis
└── scripts/                   # Automation scripts
```

### Key Configuration Files

- **Region**: `aws-infrastructure/terraform.tfvars`
- **Instance types**: `aws-infrastructure/variables.tf`
- **Karpenter policy**: `kubernetes/karpenter-nodepool.yaml`
- **HPA thresholds**: `kubernetes/hpa-v2.yaml`

### Environment Variables

After deployment, source these:

```bash
source .env

# Available variables:
# - DOCKER_MANAGER_IP
# - DOCKER_WORKER_1_IP
# - DOCKER_WORKER_2_IP
# - K8S_CONTROL_IP
# - AWS_REGION
```

---

## 📚 Research Context

This deployment supports **Objectives 2 & 3** of the PhD research:

- **Objective 2**: KMAB Framework (Karpenter Memory-Aware Bin-Packing)
- **Objective 3**: Comparative analysis across 4 load scenarios

### Expected Research Outcome

**Hypothesis**: Kubernetes with Karpenter reduces memory waste by ~71% compared to Docker Swarm through dynamic bin-packing and consolidation.

**Test Protocol**:
- Normal load (steady state)
- High load (peak performance)
- Variable load (adaptive scaling)
- Fault tolerance (recovery time)

---

## ⚠️ Important Notes

1. **Cost Management**: Remember to destroy resources after experiments
2. **Security**: SSH keys are created locally; keep them secure
3. **Region**: All resources are in ap-south-1 (Mumbai)
4. **Data Collection**: Results are saved to `./results/TIMESTAMP/`
5. **Academic Use**: This setup is for research purposes

---

## 🎓 Citation

If you use this infrastructure for your research:

```
PhD Research: Analysing Virtual CPU and Memory Usage in Docker Swarm on AWS
Comparative Study with Kubernetes Framework (Objectives 2 & 3)
Deployment Region: AWS ap-south-1
```

---

**Deployment Status**: ✅ Ready for automated deployment
**Last Updated**: March 2026
**Region**: ap-south-1 (Mumbai, India)
