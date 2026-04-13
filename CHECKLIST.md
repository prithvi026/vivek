# PhD Research Deployment Checklist

## 📋 Pre-Deployment Checklist

### Software Requirements
- [ ] AWS CLI v2.x installed
  ```bash
  aws --version
  ```
- [ ] Terraform v1.0+ installed
  ```bash
  terraform --version
  ```
- [ ] kubectl v1.28+ installed
  ```bash
  kubectl version --client
  ```
- [ ] Helm v3.x installed
  ```bash
  helm version
  ```
- [ ] Python 3.8+ installed
  ```bash
  python3 --version
  ```
- [ ] Git installed
  ```bash
  git --version
  ```

### AWS Setup
- [ ] AWS account created and active
- [ ] AWS CLI configured
  ```bash
  aws configure
  # Enter Access Key, Secret Key, Region: ap-south-1
  ```
- [ ] AWS credentials verified
  ```bash
  aws sts get-caller-identity
  ```
- [ ] IAM permissions sufficient (EC2, VPC, IAM full access)

### Project Setup
- [ ] Project downloaded to: `/c/Users/prithivikachhawa/Downloads/B2A`
- [ ] Scripts made executable
  ```bash
  chmod +x deploy.sh
  chmod +x scripts/*.sh
  chmod +x monitoring/*.sh
  ```
- [ ] SSH key available or will be auto-generated

### Cost & Budget
- [ ] Budget allocated: ~$3 USD per day
- [ ] AWS billing alerts set up (optional but recommended)
- [ ] Plan to destroy resources after experiments

---

## 🚀 Deployment Checklist

### Step 1: Deploy Infrastructure
- [ ] Navigate to project directory
  ```bash
  cd /c/Users/prithivikachhawa/Downloads/B2A
  ```
- [ ] Run deployment script
  ```bash
  ./deploy.sh
  ```
- [ ] Confirm when prompted to deploy
- [ ] Wait for completion (~15-20 minutes)

### Step 2: Verify Deployment
- [ ] Load environment variables
  ```bash
  source .env
  export KUBECONFIG=$HOME/.kube/phd-config
  ```
- [ ] Check Kubernetes cluster
  ```bash
  kubectl get nodes
  # Expected: 3 nodes (1 control-plane, 2 worker)
  ```
- [ ] Check Kubernetes pods
  ```bash
  kubectl get pods
  # Expected: cpu-stress-app pods running
  ```
- [ ] Check HPA
  ```bash
  kubectl get hpa
  # Expected: cpu-stress-hpa showing metrics
  ```
- [ ] Check Karpenter
  ```bash
  kubectl get nodepools
  kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=20
  ```
- [ ] Check Docker Swarm
  ```bash
  ssh ubuntu@$DOCKER_MANAGER_IP "docker node ls"
  # Expected: 3 nodes (1 manager, 2 workers)
  ```
- [ ] Verify connectivity to all nodes
  ```bash
  ssh ubuntu@$K8S_CONTROL_IP "echo 'K8s Control: Connected'"
  ssh ubuntu@$DOCKER_MANAGER_IP "echo 'Docker Manager: Connected'"
  ```

---

## 🧪 Experiment Execution Checklist

### Pre-Experiment
- [ ] Results directory created
  ```bash
  mkdir -p results/$(date +%Y%m%d_%H%M%S)
  ```
- [ ] Monitoring scripts tested
  ```bash
  ./monitoring/monitor_comparison.sh --test
  ```
- [ ] Baseline metrics captured
  ```bash
  kubectl top nodes
  kubectl top pods
  ```

### Running Experiments

#### Option 1: Full Test Suite (Recommended)
- [ ] Run all 4 scenarios
  ```bash
  ./scripts/run_all_tests.sh
  ```
- [ ] Monitor progress in separate terminals
  ```bash
  # Terminal 1
  watch -n 5 kubectl get pods

  # Terminal 2
  watch -n 5 kubectl get hpa

  # Terminal 3
  watch -n 5 kubectl top nodes
  ```

#### Option 2: Individual Scenarios

**Scenario 1: Normal Load (30 minutes)**
- [ ] Start normal load test
- [ ] Monitor CPU: 30-50%
- [ ] Collect metrics every 10 seconds
- [ ] Save results to CSV

**Scenario 2: High Load (20 minutes)**
- [ ] Start high load test
- [ ] Monitor CPU: 80-95%
- [ ] Observe HPA scaling behavior
- [ ] Record scaling events

**Scenario 3: Variable Load (45 minutes)**
- [ ] Start variable load test
- [ ] Monitor CPU cycling: 20-90%
- [ ] Observe adaptive scaling
- [ ] Track consolidation events

**Scenario 4: Fault Tolerance**
- [ ] Run fault tolerance script
  ```bash
  ./scripts/fault_tolerance_test.sh
  ```
- [ ] Simulate node failure
- [ ] Measure recovery time
- [ ] Verify service restoration

### Data Collection
- [ ] Kubernetes metrics saved
- [ ] Docker Swarm metrics saved
- [ ] Scaling events logged
- [ ] Response times recorded
- [ ] Memory usage tracked

---

## 📊 Analysis Checklist

### Data Preparation
- [ ] All experiment results in `./results/` directory
- [ ] CSV files properly formatted
- [ ] Timestamps synchronized
- [ ] No data corruption or gaps

### Statistical Analysis
- [ ] Run analysis script
  ```bash
  python3 analysis/analyse_results.py ./results/
  ```
- [ ] Review memory_waste_comparison.csv
  ```bash
  cat results/memory_waste_comparison.csv
  ```
- [ ] Review metric_summary.csv
  ```bash
  cat results/metric_summary.csv
  ```
- [ ] Check for expected ~71% improvement
- [ ] Verify all 4 scenarios included

### Key Metrics Verification

**Memory Waste Reduction**
- [ ] Normal load: ~69% reduction
- [ ] High load: ~70% reduction
- [ ] Variable load: ~70% reduction
- [ ] During scaling: ~73% reduction
- [ ] Average: ~71% reduction

**Performance Metrics**
- [ ] K8s CPU utilization: 90-95%
- [ ] Docker CPU utilization: 75-85%
- [ ] K8s scale-up: 15-25 seconds
- [ ] Docker scale-up: 30-45 seconds
- [ ] K8s fault recovery: 30-60 seconds
- [ ] Docker fault recovery: 2-3 minutes

### Documentation
- [ ] Results documented in research notes
- [ ] Charts and graphs generated
- [ ] Anomalies noted and explained
- [ ] Statistical significance verified
- [ ] Thesis sections drafted

---

## 🧹 Cleanup Checklist

### Pre-Cleanup
- [ ] All experiments completed
- [ ] Results backed up locally
- [ ] Important data copied to permanent storage
- [ ] Screenshots captured (if needed)
- [ ] Final metrics recorded

### Backup Verification
- [ ] Results directory backed up
  ```bash
  cp -r results/ results_backup_$(date +%Y%m%d)
  ```
- [ ] Infrastructure state saved
  ```bash
  cd aws-infrastructure
  terraform output -json > final_state.json
  ```
- [ ] Kubeconfig saved (if needed)
  ```bash
  cp $HOME/.kube/phd-config ./backup/kubeconfig
  ```

### Resource Destruction
- [ ] Run cleanup script
  ```bash
  ./scripts/destroy.sh
  ```
- [ ] Type 'DESTROY' when prompted
- [ ] Wait for Terraform destroy to complete
- [ ] Verify all resources destroyed
  ```bash
  aws ec2 describe-instances --region ap-south-1 \
    --filters "Name=tag:Project,Values=k8s-docker-comparison"
  ```
- [ ] Check for remaining VPCs
  ```bash
  aws ec2 describe-vpcs --region ap-south-1 \
    --filters "Name=tag:Project,Values=k8s-docker-comparison"
  ```
- [ ] Verify NAT Gateway deleted
  ```bash
  aws ec2 describe-nat-gateways --region ap-south-1 \
    --filter "Name=tag:Project,Values=k8s-docker-comparison"
  ```

### Post-Cleanup
- [ ] AWS Console checked for lingering resources
- [ ] Billing dashboard reviewed
- [ ] Final costs calculated
- [ ] Local files cleaned (optional)
  ```bash
  rm -f .env
  rm -f $HOME/.kube/phd-config
  ```

---

## 📝 Troubleshooting Checklist

### If Deployment Fails

**Terraform Issues**
- [ ] Check AWS credentials
  ```bash
  aws sts get-caller-identity
  ```
- [ ] Verify region availability
  ```bash
  aws ec2 describe-availability-zones --region ap-south-1
  ```
- [ ] Re-initialize Terraform
  ```bash
  cd aws-infrastructure
  terraform init -upgrade
  ```
- [ ] Check for resource limits in AWS account

**kubectl Connection Issues**
- [ ] Verify kubeconfig exists
  ```bash
  ls -la $HOME/.kube/phd-config
  ```
- [ ] Check kubeconfig content
  ```bash
  kubectl config view
  ```
- [ ] Test with verbose output
  ```bash
  kubectl get nodes -v=6
  ```
- [ ] SSH to control plane and check kubelet
  ```bash
  ssh ubuntu@$K8S_CONTROL_IP "sudo systemctl status kubelet"
  ```

**Karpenter Issues**
- [ ] Check Karpenter logs
  ```bash
  kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=50
  ```
- [ ] Verify NodePool exists
  ```bash
  kubectl get nodepools
  ```
- [ ] Check EC2NodeClass
  ```bash
  kubectl get ec2nodeclasses
  ```
- [ ] Verify IAM permissions
  ```bash
  kubectl describe nodepool memory-optimised-pool
  ```

**HPA Not Scaling**
- [ ] Check Metrics Server
  ```bash
  kubectl get pods -n kube-system | grep metrics-server
  kubectl top nodes
  ```
- [ ] Describe HPA for errors
  ```bash
  kubectl describe hpa cpu-stress-hpa
  ```
- [ ] Verify pod resource requests
  ```bash
  kubectl describe pod <pod-name> | grep -A 5 Resources
  ```
- [ ] Check HPA events
  ```bash
  kubectl get events --sort-by='.lastTimestamp' | grep HPA
  ```

**Docker Swarm Issues**
- [ ] Check swarm status
  ```bash
  ssh ubuntu@$DOCKER_MANAGER_IP "docker info | grep Swarm"
  ```
- [ ] Regenerate join token
  ```bash
  ssh ubuntu@$DOCKER_MANAGER_IP "docker swarm join-token worker"
  ```
- [ ] Verify ports are open
  ```bash
  ssh ubuntu@$DOCKER_MANAGER_IP "sudo netstat -tlnp | grep 2377"
  ```
- [ ] Check worker connectivity
  ```bash
  ssh ubuntu@$DOCKER_WORKER_1_IP "docker info"
  ```

---

## ✅ Success Criteria

### Deployment Success
- [x] All scripts executable
- [x] Terraform configuration for ap-south-1
- [ ] All 6 EC2 instances running
- [ ] Kubernetes cluster operational (3 nodes)
- [ ] Docker Swarm cluster operational (3 nodes)
- [ ] Karpenter controller running
- [ ] Metrics Server providing data
- [ ] HPA showing current metrics
- [ ] Applications responding to health checks

### Experiment Success
- [ ] All 4 scenarios completed
- [ ] Data collected for each scenario
- [ ] No extended downtime during tests
- [ ] Metrics captured at proper intervals
- [ ] Scaling events recorded
- [ ] Fault tolerance recovery documented

### Analysis Success
- [ ] Memory waste reduction calculated
- [ ] ~71% improvement demonstrated (±5%)
- [ ] All performance metrics collected
- [ ] Statistical analysis complete
- [ ] Results documented
- [ ] Charts/graphs generated

### Research Success
- [ ] Hypothesis validated or refuted
- [ ] KMAB framework proven effective
- [ ] Comparative data collected
- [ ] Findings support thesis
- [ ] Ready for publication/defense

---

## 📅 Timeline Estimate

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Pre-deployment setup | 10 min | 10 min |
| Infrastructure deployment | 20 min | 30 min |
| Verification | 10 min | 40 min |
| **Ready to experiment** | | **40 min** |
| Scenario 1 (Normal Load) | 30 min | 70 min |
| Scenario 2 (High Load) | 20 min | 90 min |
| Scenario 3 (Variable Load) | 45 min | 135 min |
| Scenario 4 (Fault Tolerance) | 30 min | 165 min |
| **All experiments complete** | | **~3 hours** |
| Data analysis | 30 min | 195 min |
| Report generation | 30 min | 225 min |
| Cleanup | 15 min | 240 min |
| **Total project time** | | **~4 hours** |

---

## 🎯 Final Checklist

Before submitting your thesis:
- [ ] All experiments completed successfully
- [ ] Results show expected ~71% improvement
- [ ] All data backed up securely
- [ ] AWS resources destroyed
- [ ] Final billing verified
- [ ] Code and configs documented
- [ ] Results reproducible
- [ ] Peer review completed
- [ ] Thesis sections written
- [ ] Ready for defense! 🎓

---

**Good luck with your PhD research!** 🎓🚀

---

**Last Updated**: March 29, 2026
**Status**: Ready for deployment
**Region**: ap-south-1 (Mumbai, India)
