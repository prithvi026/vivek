# 🔥 LOAD TEST ACTIVE - METRICS SPIKING NOW!

**Status:** ✅ LOAD TESTS RUNNING  
**Duration:** 10 minutes (600 seconds)  
**Started:** Just now

---

## 📊 WHAT'S RUNNING:

### **1. Nginx Web Servers (10 replicas)**
- **Purpose:** Test pod distribution and scheduling
- **Resource usage:** Low CPU, minimal memory
- **Pods:** Distributed across both worker nodes

### **2. CPU Stress Test (3 replicas)**
- **Command:** `stress --cpu 2 --timeout 600s`
- **Purpose:** Generate CPU load for performance testing
- **Expected impact:** CPU usage should spike to 40-60%
- **Duration:** 10 minutes

### **3. Memory Stress Test (2 replicas)**
- **Command:** `stress --vm 1 --vm-bytes 256M --timeout 600s`
- **Purpose:** Generate memory pressure
- **Expected impact:** Memory usage increase by ~512MB total
- **Duration:** 10 minutes

---

## 📈 WHAT TO SEE IN GRAFANA:

### **Immediate Effects (within 1-2 minutes):**

1. **CPU Usage Graph:**
   - Should show significant spike on nodes running cpu-stress pods
   - Look for lines jumping from ~5-10% to 40-60%
   - ip-10-0-1-212 (Worker 2) will show highest load

2. **Memory Usage Graph:**
   - Gradual increase as memory-stress pods allocate memory
   - Watch for 250-500MB increase per node

3. **Pod Count:**
   - Total pods increased from 3 to 15
   - Shows cluster scaling capability

4. **Network Traffic:**
   - Slight increase from pod-to-pod communication

---

## 🎯 GRAFANA DASHBOARD TIPS:

### **Best Views for Screenshots:**

1. **Time Range Settings (Top Right):**
   - Change to: **"Last 15 minutes"** or **"Last 30 minutes"**
   - Set refresh: **"5s"** (auto-refresh every 5 seconds)

2. **What to Capture:**
   
   **Screenshot 1: Overview (Now)**
   - Full dashboard showing baseline metrics
   - Capture BEFORE load spikes (for comparison)

   **Screenshot 2: During Load (2-3 minutes from now)**
   - CPU graphs showing spike
   - Memory increasing
   - All pods running
   - *This shows cluster under stress*

   **Screenshot 3: Resource Distribution**
   - Show how load is distributed across nodes
   - Zoom in on specific node metrics
   - *Demonstrates load balancing*

   **Screenshot 4: After 10 minutes**
   - Load tests will automatically stop
   - Capture metrics returning to baseline
   - *Shows cluster recovery*

---

## 📸 SCREENSHOT CHECKLIST FOR PhD THESIS:

- [ ] **Baseline metrics** (captured before load)
- [ ] **CPU spike during stress test** (peak usage)
- [ ] **Memory utilization increase** (real-time)
- [ ] **Pod distribution across nodes** (scheduling)
- [ ] **Network traffic patterns** (communication)
- [ ] **Node comparison view** (show all 3 nodes)
- [ ] **Recovery to baseline** (after 10 min)
- [ ] **Prometheus query examples** (use Explore feature)

---

## 🔍 ADVANCED: PROMETHEUS QUERIES

Use Grafana's **Explore** (🧭 icon) to run custom queries:

### **CPU Usage by Pod:**
```promql
rate(container_cpu_usage_seconds_total{namespace="default"}[5m])
```

### **Memory Usage by Pod:**
```promql
container_memory_working_set_bytes{namespace="default"}
```

### **Pod Count per Node:**
```promql
count(kube_pod_info) by (node)
```

### **CPU Load Comparison:**
```promql
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

---

## 📊 CURRENT DEPLOYMENT STATUS:

| Deployment | Replicas | Purpose | Status |
|-----------|----------|---------|--------|
| **nginx** | 10 | Web servers | ✅ Running |
| **cpu-stress** | 3 | CPU load | ✅ Running |
| **memory-stress** | 2 | Memory load | ✅ Running |
| **Total Pods** | 15 | Mixed workload | ✅ Active |

**Distribution:**
- ip-10-0-1-212 (Worker 2): ~7 pods
- ip-10-0-1-192 (Worker 1): ~8 pods
- ip-10-0-1-20 (Control Plane): Monitoring stack only

---

## ⏱️ TIMELINE:

| Time | Action | Expected Result |
|------|--------|-----------------|
| **00:00** (Now) | Load tests started | Pods creating |
| **01:00** | All pods running | CPU spike begins |
| **02:00** | Full load active | Metrics at peak |
| **05:00** | Mid-test | Stable high load |
| **10:00** | Tests complete | Pods terminate |
| **11:00** | Cleanup | Return to baseline |

---

## 🎓 FOR YOUR PhD DOCUMENTATION:

### **Key Observations to Document:**

1. **Scheduling Efficiency**
   - How quickly did Kubernetes schedule 15 pods?
   - How were pods distributed across nodes?
   - Any pods stuck in Pending state? (indicates resource constraints)

2. **Resource Utilization**
   - Peak CPU % achieved
   - Peak memory usage
   - Did any node hit resource limits?

3. **Performance Under Load**
   - Response time of Kubernetes API
   - Time to scale from 3 to 15 pods
   - Pod creation latency

4. **Cluster Stability**
   - Did any pods crash or restart?
   - Network connectivity maintained?
   - Monitoring stack remained operational?

### **Comparison Points for Objective 3:**

Later, run the same tests on Docker Swarm and compare:
- Scheduling speed
- Resource efficiency
- Monitoring capabilities
- Ease of deployment

---

## 🛑 STOP LOAD TESTS (If Needed):

If you need to stop the tests early:

```bash
ssh -i ~/.ssh/id_rsa ubuntu@52.66.203.212
kubectl delete deployment cpu-stress memory-stress
kubectl scale deployment nginx --replicas=3
```

Otherwise, they'll auto-stop after 10 minutes.

---

## 🔄 RESTART/EXTEND LOAD TESTS:

To run again or extend duration:

```bash
ssh -i ~/.ssh/id_rsa ubuntu@52.66.203.212

# CPU stress (change 600s to extend)
kubectl create deployment cpu-stress --image=polinux/stress --replicas=3 -- stress --cpu 2 --timeout 600s

# Memory stress
kubectl create deployment memory-stress --image=polinux/stress --replicas=2 -- stress --vm 1 --vm-bytes 256M --timeout 600s

# Scale nginx
kubectl scale deployment nginx --replicas=10
```

---

## 📱 MONITOR PROGRESS:

### **Via Grafana (Visual):**
- http://52.66.203.212:30300
- Watch graphs update every 5 seconds

### **Via SSH (Command Line):**
```bash
ssh -i ~/.ssh/id_rsa ubuntu@52.66.203.212

# Watch pod status
watch -n 5 kubectl get pods

# Check CPU usage
kubectl top nodes

# See events
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

---

## ✅ SUCCESS CRITERIA:

Your load test is working if you see:
- ✅ CPU graphs showing 40-60% usage (up from ~5%)
- ✅ Memory usage increased by 500MB-1GB
- ✅ 15 pods running (some may be creating)
- ✅ Network traffic increase visible
- ✅ All monitoring dashboards still responsive

---

## 💡 PRO TIPS:

1. **Take screenshots DURING the spike** (not just after)
2. **Use light theme** for better printing (Settings → Preferences → Theme)
3. **Annotate graphs** in your thesis to explain what's happening
4. **Compare baseline vs load** side-by-side
5. **Capture multiple time ranges** (5min, 15min, 30min views)
6. **Don't forget Prometheus** - http://52.66.203.212:30900

---

**🎓 Your cluster is now under load! Go to Grafana and start capturing those screenshots!**

**Grafana:** http://52.66.203.212:30300  
**Prometheus:** http://52.66.203.212:30900

**Load test duration:** 10 minutes from now  
**Status:** 🔥 ACTIVE

---

**Created:** April 4, 2026  
**Load Tests:** cpu-stress (3), memory-stress (2), nginx (10)  
**Total Pods:** 15 active workloads
