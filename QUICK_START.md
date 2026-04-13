# 🚀 Quick Start Guide
## PhD Research: Kubernetes vs Docker Swarm on AWS

**Region**: ap-south-1 (Mumbai, India)
**Estimated Setup Time**: 15-20 minutes
**Estimated Cost**: $2-3 USD per day

---

## Prerequisites Checklist

Before running the deployment, ensure you have:

- [ ] AWS Account with active credentials
- [ ] AWS CLI installed and configured (`aws --version`)
- [ ] Terraform installed (`terraform --version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] Helm installed (`helm version`)
- [ ] SSH key or ability to generate one
- [ ] ~$3/day budget for AWS resources

---

## Step-by-Step Deployment

### 1️⃣ Configure AWS Credentials

```bash
# Set up your AWS credentials
aws configure

# Verify configuration
aws sts get-caller-identity
```

**Required AWS Permissions:**
- EC2 (full access)
- VPC (full access)
- IAM (roles and policies)

---

### 2️⃣ Prepare the Project

```bash
# Navigate to project directory
cd /c/Users/prithivikachhawa/Downloads/B2A

# Make scripts executable
chmod +x deploy.sh
chmod +x scripts/*.sh
chmod +x monitoring/*.sh

# Verify project structure
ls -la
```

---

### 3️⃣ Run Automated Deployment

```bash
# Start the automated deployment
./deploy.sh
```

**What happens during deployment:**

1. ✅ Pre-flight checks (AWS CLI, Terraform, kubectl, Helm)
2. ✅ Creates/validates SSH key pair
3. ✅ Deploys AWS infrastructure (VPC, subnets, EC2 instances)
4. ✅ Waits for instances to initialize (~3 minutes)
5. ✅ Configures Kubernetes cluster with kubeconfig
6. ✅ Installs Karpenter and Metrics Server
7. ✅ Deploys CPU stress application with HPA
8. ✅ Configures Docker Swarm cluster
9. ✅ Displays connection information

**Duration:** 15-20 minutes total

---

### 4️⃣ Verify Deployment

```bash
# Load environment variables
source .env
export KUBECONFIG=$HOME/.kube/phd-config

# Check Kubernetes cluster
kubectl get nodes
kubectl get pods

# Check Docker Swarm
ssh ubuntu@$DOCKER_MANAGER_IP "docker node ls"
```

**Expected Output:**

```
Kubernetes:
- 1 control plane node (t3.medium)
- 2 worker nodes (t2.micro)
- cpu-stress-app pods running

Docker Swarm:
- 1 manager node
- 2 worker nodes
```

---

## Running Experiments

### Full Test Suite (All 4 Scenarios)

```bash
./scripts/run_all_tests.sh
```

**Scenarios Included:**
1. Normal Load (30-50% CPU) - 30 minutes
2. High Load (80-95% CPU) - 20 minutes
3. Variable Load (20-90% cycling) - 45 minutes
4. Fault Tolerance (node failure) - until recovery

**Total Experiment Time**: ~2 hours

---

### Individual Scenario Testing

```bash
# Normal load
kubectl exec -it <pod-name> -- curl "http://localhost:8081/start_cpu_stress?duration=1800"

# High load
kubectl exec -it <pod-name> -- curl "http://localhost:8081/start_cpu_stress?duration=1200"

# Monitor in real-time
watch -n 5 kubectl get hpa
```

---

### Real-Time Monitoring

```bash
# Terminal 1: Kubernetes monitoring
kubectl get pods -w

# Terminal 2: HPA monitoring
watch -n 5 kubectl get hpa

# Terminal 3: Node monitoring
watch -n 5 kubectl top nodes

# Terminal 4: Docker Swarm monitoring
ssh ubuntu@$DOCKER_MANAGER_IP "watch -n 5 docker service ps my-cpu-stressor"
```

---

## Analyzing Results

### Generate Analysis Report

```bash
# Run analysis script
python3 analysis/analyse_results.py ./results/

# View results
cat results/memory_waste_comparison.csv
cat results/metric_summary.csv
```

### Key Metrics to Review

| Metric | Expected Result |
|--------|----------------|
| Memory Waste Reduction | ~71% improvement |
| CPU Utilization | K8s: 90-95%, Docker: 75-85% |
| Scale-up Speed | K8s: 15-25s, Docker: 30-45s |
| Fault Recovery | K8s: 30-60s, Docker: 2-3 min |

---

## Cleanup and Destroy

### ⚠️ Important: Destroy Resources After Experiments

```bash
# Automated cleanup
./scripts/destroy.sh

# Type 'DESTROY' when prompted to confirm
```

**What gets destroyed:**
- All EC2 instances
- VPC and networking components
- NAT Gateway
- Security groups
- IAM roles

**What gets preserved:**
- Experimental results (backed up automatically)
- Infrastructure state (saved to JSON)
- Local configuration files (optional removal)

---

## Troubleshooting

### Issue 1: Terraform Apply Fails

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check region availability
aws ec2 describe-availability-zones --region ap-south-1

# Re-initialize Terraform
cd aws-infrastructure
terraform init -upgrade
```

### Issue 2: kubectl Connection Fails

```bash
# Verify kubeconfig
export KUBECONFIG=$HOME/.kube/phd-config
kubectl config view

# Test connection with verbose output
kubectl get nodes -v=6

# SSH to control plane and check kubelet
ssh ubuntu@$K8S_CONTROL_IP "sudo systemctl status kubelet"
```

### Issue 3: Karpenter Not Provisioning

```bash
# Check Karpenter logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=50

# Verify NodePool
kubectl get nodepools

# Check for pending pods
kubectl get pods --field-selector=status.phase=Pending
```

### Issue 4: HPA Not Scaling

```bash
# Check HPA status
kubectl describe hpa cpu-stress-hpa

# Verify Metrics Server
kubectl get pods -n kube-system | grep metrics-server
kubectl top nodes

# Check pod resource requests
kubectl describe pod <pod-name> | grep -A 5 Resources
```

---

## Cost Management

### Monitor AWS Costs

```bash
# Check current costs
aws ce get-cost-and-usage \
  --time-period Start=2026-03-01,End=2026-03-31 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Set up billing alerts in AWS Console
# Recommended: Set alert at $5 USD
```

### Resource Pricing (ap-south-1)

| Resource | Type | Hourly Cost | Daily Cost |
|----------|------|-------------|------------|
| t3.medium | Control plane | ~$0.046 | ~$1.10 |
| t2.micro (5x) | Workers | ~$0.012 each | ~$1.44 total |
| NAT Gateway | Networking | ~$0.048 | ~$1.15 |
| **Total** | | | **~$2.50-3.00/day** |

---

## Project Structure

```
B2A/
├── deploy.sh                          # ⭐ Main deployment script
├── QUICK_START.md                     # This file
├── DEPLOYMENT_GUIDE.md                # Detailed documentation
├── README.md                          # Research documentation
├── .env                               # Environment variables (generated)
│
├── aws-infrastructure/                # Terraform infrastructure
│   ├── main.tf                        # AWS resource definitions
│   ├── variables.tf                   # Configuration variables
│   ├── outputs.tf                     # Output values
│   ├── terraform.tfvars              # Region: ap-south-1
│   └── user_data/                     # Instance initialization scripts
│
├── kubernetes/                        # Kubernetes manifests
│   ├── karpenter-nodepool.yaml       # KMAB framework implementation
│   ├── cpu-stress-deployment-karpenter.yaml
│   └── hpa-v2.yaml                   # Horizontal Pod Autoscaler
│
├── docker-swarm/                     # Docker Swarm configs
│   └── docker-compose.yml
│
├── applications/                     # CPU stress application
│   └── cpu_stress_app.py             # Flask-based stress testing app
│
├── monitoring/                       # Monitoring scripts
│   └── monitor_comparison.sh         # Real-time comparison monitoring
│
├── scripts/                          # Automation scripts
│   ├── run_all_tests.sh             # Run all 4 test scenarios
│   ├── fault_tolerance_test.sh      # Scenario 4: Fault tolerance
│   └── destroy.sh                    # ⚠️ Cleanup script
│
└── analysis/                         # Results analysis
    └── analyse_results.py            # Statistical analysis script
```

---

## Environment Variables

After deployment, these variables are available in `.env`:

```bash
DOCKER_MANAGER_IP=<public-ip>        # Docker Swarm manager
DOCKER_WORKER_1_IP=<public-ip>       # Docker worker 1
DOCKER_WORKER_2_IP=<public-ip>       # Docker worker 2
K8S_CONTROL_IP=<public-ip>           # Kubernetes control plane
AWS_REGION=ap-south-1                # AWS region
```

**Usage:**
```bash
source .env
ssh ubuntu@$DOCKER_MANAGER_IP
```

---

## Next Steps After Deployment

1. **Verify Deployment**
   ```bash
   kubectl get nodes
   kubectl get pods
   ssh ubuntu@$DOCKER_MANAGER_IP "docker node ls"
   ```

2. **Run Baseline Tests**
   ```bash
   ./scripts/run_all_tests.sh
   ```

3. **Collect Data**
   - Results saved to: `./results/TIMESTAMP/`
   - Logs saved to: `./logs/`

4. **Analyze Results**
   ```bash
   python3 analysis/analyse_results.py ./results/
   ```

5. **Generate Report**
   - Review CSV files in `results/`
   - Check visualizations in `results/charts/`
   - Document findings for thesis

6. **Cleanup**
   ```bash
   ./scripts/destroy.sh
   ```

---

## Support and Resources

### Documentation
- Full Guide: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- Research Context: [README.md](README.md)
- Terraform Docs: [aws-infrastructure/README.md](aws-infrastructure/README.md)

### Useful Commands

```bash
# Check infrastructure status
cd aws-infrastructure && terraform show

# View all outputs
terraform output

# SSH to control plane
ssh -i ~/.ssh/id_rsa ubuntu@$(terraform output -raw k8s_control_plane_public_ip)

# Get kubeconfig
export KUBECONFIG=$HOME/.kube/phd-config

# Monitor Karpenter
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f
```

---

## Success Indicators

✅ **Deployment Successful When:**

- [ ] `kubectl get nodes` shows 3 nodes (1 control, 2 workers)
- [ ] `kubectl get pods` shows cpu-stress-app pods running
- [ ] `kubectl get hpa` shows HPA with metrics
- [ ] `ssh ubuntu@$DOCKER_MANAGER_IP "docker node ls"` shows 3 nodes
- [ ] All instances are accessible via SSH
- [ ] Metrics Server is running and providing data

---

## Research Objectives

This deployment supports:

- **Objective 2**: KMAB Framework (Karpenter Memory-Aware Bin-Packing)
  - Phase 1: Observation
  - Phase 2: Bin-pack optimization
  - Phase 3: Provisioning
  - Phase 4: Real-time scaling (HPA)
  - Phase 5: Consolidation

- **Objective 3**: Comparative Analysis
  - Normal load scenario
  - High load scenario
  - Variable load scenario
  - Fault tolerance scenario

**Target Finding**: ~71% memory waste reduction with Kubernetes vs Docker Swarm

---

## Important Notes

⚠️ **Security**
- SSH keys are stored locally at `~/.ssh/id_rsa`
- EC2 instances have public IPs for research access
- Security groups restrict access appropriately

⚠️ **Costs**
- Estimated $2-3 USD per day
- NAT Gateway is the most expensive component
- Destroy resources immediately after experiments

⚠️ **Data**
- All experimental data is saved locally
- Backup important results before destroying infrastructure
- Results are automatically backed up during cleanup

---

**Deployment Status**: ✅ Ready for one-command deployment
**Last Updated**: March 2026
**Region**: ap-south-1 (Mumbai, India)

---

## One-Line Deployment

```bash
chmod +x deploy.sh && ./deploy.sh
```

That's it! The script handles everything automatically. 🎉
