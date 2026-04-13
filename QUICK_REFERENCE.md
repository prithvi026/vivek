# QUICK REFERENCE - COPY THESE COMMANDS

## 🚀 QUICK START (5 Commands to Begin)

```bash
# 1. Navigate to project
cd /c/Users/prithivikachhawa/Downloads/B2A

# 2. Verify AWS access
aws sts get-caller-identity

# 3. Create cluster config (copy from main guide)
# Then create cluster
eksctl create cluster -f security-research-cluster.yml

# 4. Wait 20 minutes, then verify
kubectl get nodes

# 5. Start installing drivers (see below)
```

---

## 📦 INSTALLATION COMMANDS (Sequential)

```bash
# EBS Driver
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.24"

# Storage Classes
kubectl apply -f unencrypted-ebs.yml
kubectl apply -f encrypted-ebs.yml

# Test Applications
kubectl apply -f unencrypted-app.yml
kubectl apply -f encrypted-app.yml

# Verify
kubectl get pods
kubectl get pvc
kubectl get storageclass
```

---

## 🔴 ATTACK SIMULATION COMMANDS

```bash
# Data Exfiltration
kubectl exec -it deployment/unencrypted-app -- sh
# Inside: cat /data/financial-data.txt

# Privilege Escalation
kubectl apply -f privileged-attacker.yml
kubectl exec -it privileged-attacker -- sh
# Inside: id, ls /host

# Access Comparison
kubectl exec deployment/unencrypted-app -- cat /data/financial-data.txt
kubectl exec deployment/encrypted-app -- cat /data/financial-data.txt
```

---

## 🛡️ SECURITY TESTING COMMANDS

```bash
# RBAC
kubectl auth can-i get pvc
kubectl auth can-i delete pvc
kubectl apply -f restricted-user.yml
kubectl auth can-i get pvc --as=system:serviceaccount:default:restricted-user

# Pod Security
kubectl apply -f insecure-pod.yml
kubectl apply -f secure-pod.yml
kubectl exec insecure-pod -- id
kubectl exec secure-pod -- id

# Network Policy
kubectl get pods -o wide
kubectl exec <pod1> -- ping -c 3 <pod2-ip>
kubectl apply -f network-policy.yml
kubectl exec <pod1> -- ping -c 3 <pod2-ip>
```

---

## ⚡ PERFORMANCE TESTING

```bash
# Unencrypted Write
kubectl exec deployment/unencrypted-app -- sh -c "time dd if=/dev/zero of=/data/testfile bs=1M count=500 2>&1"

# Encrypted Write
kubectl exec deployment/encrypted-app -- sh -c "time dd if=/dev/zero of=/data/testfile bs=1M count=500 2>&1"

# Compare results
```

---

## 📸 SCREENSHOTS TO TAKE

- [ ] `kubectl get nodes` - Cluster created
- [ ] `kubectl get pods -A` - All pods running
- [ ] Data exfiltration - financial data visible
- [ ] Privilege escalation - id showing uid=0
- [ ] RBAC comparison - yes vs no
- [ ] Pod security - uid=0 vs uid=1000
- [ ] Network policy - ping before/after
- [ ] Performance - unencrypted time
- [ ] Performance - encrypted time
- [ ] Kube-bench results summary

---

## 🧹 CLEANUP (Run at end)

```bash
# Delete test resources
kubectl delete pod privileged-attacker insecure-pod secure-pod
kubectl delete deployment unencrypted-app encrypted-app
kubectl delete pvc unencrypted-pvc encrypted-pvc

# DELETE CLUSTER (saves money)
eksctl delete cluster --name security-research-cluster --region ap-south-1
```

---

## 🆘 EMERGENCY COMMANDS

```bash
# If stuck
kubectl get events --sort-by='.lastTimestamp' | tail -20

# If pod not starting
kubectl describe pod <pod-name>

# If PVC not binding
kubectl describe pvc <pvc-name>

# Check logs
kubectl logs <pod-name>

# Force delete stuck pod
kubectl delete pod <pod-name> --grace-period=0 --force
```

---

## 💰 COST TRACKING

```bash
# Check running instances
aws ec2 describe-instances --region ap-south-1 --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]' --output table

# Estimated cost: ~$0.80/hour for 3 t3.medium nodes
# Total for 3 hours: ~$2.40
```

---

## ✅ COMPLETION CHECKLIST

- [ ] Cluster created and verified
- [ ] Storage drivers installed
- [ ] Test apps deployed and running
- [ ] Attack simulations completed (3 tests)
- [ ] Security mechanisms tested (3 tests)
- [ ] Performance benchmarks collected
- [ ] All screenshots taken (10+)
- [ ] Evidence collected
- [ ] Cluster deleted

---

## 📞 WHAT TO DO IF...

**Cluster creation fails:**
- Check AWS credentials: `aws sts get-caller-identity`
- Check region quotas: AWS Console > EC2 > Limits
- Try different region or smaller instances

**Pods stuck in Pending:**
- Check node capacity: `kubectl describe nodes`
- Check events: `kubectl get events`
- May need to wait for EBS volumes to attach

**Out of credits/budget:**
- Stop immediately: `eksctl delete cluster --name security-research-cluster`
- Use local Kubernetes (minikube) for practice
- Generate outputs theoretically

---

## 🎯 SUCCESS METRICS

At the end, you should have:
- ✅ 15-20 terminal screenshots
- ✅ Attack vulnerabilities demonstrated
- ✅ Security improvements shown
- ✅ Performance data collected
- ✅ Total cost: <$3
- ✅ Total time: ~3 hours

**Ready for Objective 2! 🚀**
