# 🎉 PhD Research Infrastructure - DEPLOYMENT COMPLETE!

**Date:** April 4, 2026  
**Region:** AWS ap-south-1 (Mumbai)  
**Status:** ✅ FULLY OPERATIONAL

---

## 📊 QUICK ACCESS

### **Grafana Dashboard** (Recommended)
**URL:** http://52.66.203.212:30300

**Login Credentials:**
- Username: `admin`
- Password: `admin`

### **Prometheus** (Advanced Users)
**URL:** http://52.66.203.212:30900

---

## 🏗️ INFRASTRUCTURE OVERVIEW

### **Kubernetes Cluster** (3 nodes)
| Node | Type | Instance Type | Private IP | Public IP | RAM |
|------|------|---------------|------------|-----------|-----|
| Control Plane | t3.medium | i-07999b55b2cadfbf1 | 10.0.1.20 | 52.66.203.212 | 4GB |
| Worker 1 | t2.micro | i-04f3b6ca09347c72c | 10.0.1.212 | 15.207.86.110 | 1GB |
| Worker 2 | t2.micro | i-0ca109c0bd7cc2e07 | 10.0.1.192 | 15.206.145.215 | 1GB |

### **Docker Swarm Cluster** (3 nodes)
| Node | Type | Instance Type | Private IP | Public IP |
|------|------|---------------|------------|-----------|
| Manager | t3.medium | i-0b29936a42d4ee138 | 10.0.1.211 | 15.207.86.193 |
| Worker 1 | t2.micro | i-090606d00ffbe6bfc | 10.0.1.14 | 65.0.98.185 |
| Worker 2 | t2.micro | i-05f9236aee3df3cf7 | 10.0.1.234 | 13.126.164.39 |

---

## 📈 MONITORING STACK

### **What's Deployed:**
- ✅ **Grafana** - Running on control plane (port 30300)
- ✅ **Prometheus** - Collecting metrics every 15 seconds (port 30900)
- ✅ **Node Exporters** - Running on all 3 Kubernetes nodes
- ✅ **Alertmanager** - For alert notifications
- ✅ **Kube-state-metrics** - Kubernetes cluster metrics

### **Metrics Being Collected:**
- CPU usage per node
- Memory utilization
- Disk usage
- Network traffic
- Pod resource consumption
- Container metrics

---

## 🚀 HOW TO USE GRAFANA

### **Step 1: Access Grafana**
1. Open your browser
2. Go to: http://52.66.203.212:30300
3. Login with: `admin` / `admin`
4. (Optional) Change password when prompted

### **Step 2: Import Dashboard**

#### **Option A: Import Dashboard 1860** (Pre-built, popular)
1. Click **"+"** icon → **"Import"**
2. Enter dashboard ID: **1860**
3. Click **"Load"**
4. Select datasource: **"Prometheus"**
5. Click **"Import"**

#### **Option B: Import Custom PhD Dashboard** (Tailored for your setup)
1. Click **"+"** icon → **"Import"**
2. Click **"Upload JSON file"**
3. Select: `C:\Users\prithivikachhawa\Downloads\B2A\phd-node-dashboard.json`
4. Click **"Import"**

### **Step 3: Explore Data**

You can also use **"Explore"** (compass icon 🧭) to run custom queries:

```promql
# CPU usage
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage %
100 - ((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100)

# Node status
up{job="node-exporter"}

# Network traffic
rate(node_network_receive_bytes_total[5m])
```

---

## 📸 TAKING SCREENSHOTS FOR YOUR THESIS

### **Screenshot Checklist:**

- [ ] **Dashboard Overview** - Full cluster metrics view
  - Press F11 for fullscreen
  - Set time range: "Last 30 minutes"
  - Set refresh: "5s"
  
- [ ] **Individual Node Metrics**
  - Switch between nodes using dropdown
  - Capture CPU graphs under load
  - Capture memory utilization trends

- [ ] **Load Testing Results**
  - Generate load (see commands below)
  - Wait 2-3 minutes for data
  - Capture spike in metrics

- [ ] **Node Comparison View**
  - Show all 3 nodes side-by-side
  - Highlight resource distribution

### **Optional: Switch to Light Theme** (Better for printing)
1. Click your profile icon (bottom left)
2. Go to **"Preferences"**
3. Select **"Light"** theme
4. Click **"Save"**

---

## 🔥 GENERATE LOAD FOR DEMONSTRATION

### **Method 1: Scale nginx deployment**
```bash
ssh -i ~/.ssh/id_rsa ubuntu@52.66.203.212
kubectl scale deployment nginx --replicas=10
```

### **Method 2: Deploy stress test**
```bash
ssh -i ~/.ssh/id_rsa ubuntu@52.66.203.212
kubectl run stress --image=polinux/stress --restart=Never -- stress --cpu 2 --timeout 300s
```

Wait 2-3 minutes, then check Grafana - you'll see metrics spike! 📈

---

## 🔧 USEFUL COMMANDS

### **SSH Access:**
```bash
# Kubernetes control plane
ssh -i ~/.ssh/id_rsa ubuntu@52.66.203.212

# Kubernetes worker 1
ssh -i ~/.ssh/id_rsa ubuntu@15.207.86.110

# Kubernetes worker 2
ssh -i ~/.ssh/id_rsa ubuntu@15.206.145.215

# Docker Swarm manager
ssh -i ~/.ssh/id_rsa ubuntu@15.207.86.193
```

### **Kubernetes Commands:**
```bash
# View all nodes
kubectl get nodes -o wide

# View all pods in monitoring namespace
kubectl get pods -n monitoring

# View nginx deployment
kubectl get pods -l app=nginx -o wide

# Check node metrics (if working)
kubectl top nodes

# View Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana --tail=50
```

### **Check Grafana Status:**
```bash
ssh -i ~/.ssh/id_rsa ubuntu@52.66.203.212
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
```

---

## 🎓 FOR YOUR PhD THESIS

### **Objective 3: Comparative Analysis**

Your setup is perfect for comparing Kubernetes vs Docker Swarm:

**What to document:**
1. **Resource Efficiency**
   - CPU utilization under identical workloads
   - Memory overhead comparison
   - Network throughput

2. **Scalability**
   - Time to scale from 3 to 10 replicas
   - Resource distribution patterns
   - Load balancing efficiency

3. **Monitoring Capabilities**
   - Grafana dashboards show Kubernetes metrics in real-time
   - Compare with Docker Swarm's native monitoring

4. **KMAB Framework** (if implementing)
   - Memory waste calculation
   - Bin-packing optimization
   - Node consolidation patterns

### **Key Metrics to Capture:**
- CPU usage before/during/after scaling
- Memory allocation patterns
- Pod/container density per node
- Network latency and throughput
- Time-to-ready for new pods

---

## 🆘 TROUBLESHOOTING

### **Grafana not accessible?**
```bash
# Check if pods are running
ssh -i ~/.ssh/id_rsa ubuntu@52.66.203.212
kubectl get pods -n monitoring

# Restart Grafana if needed
kubectl rollout restart deployment -n monitoring monitoring-grafana
```

### **No data in dashboards?**
1. Wait 2-3 minutes for initial metrics collection
2. Check Prometheus is running: http://52.66.203.212:30900
3. Verify node exporters: `kubectl get pods -n monitoring | grep node-exporter`
4. Use Grafana "Explore" to test queries directly

### **Can't SSH to nodes?**
- Check your SSH key is in `~/.ssh/id_rsa`
- Verify security group allows SSH from your IP
- Wait 30 seconds if instance just started

---

## 📁 FILES CREATED

| File | Purpose |
|------|---------|
| `.env` | IP addresses and configuration |
| `phd-node-dashboard.json` | Custom Grafana dashboard |
| `access_grafana.bat` | Quick access script (alternative method) |
| `k8s_join_command.sh` | Kubernetes worker join command |
| `DEPLOYMENT_COMPLETE.md` | This file |

---

## 🎯 NEXT STEPS

1. ✅ **Access Grafana** → http://52.66.203.212:30300
2. ✅ **Import Dashboard** → Use Dashboard 1860 or custom JSON
3. ✅ **Generate Load** → Scale nginx or run stress test
4. ✅ **Take Screenshots** → Capture different views for thesis
5. ✅ **Document Findings** → Record metrics and observations

---

## 🔒 CLEANUP (When Done)

**To destroy all infrastructure:**
```bash
cd /c/Users/prithivikachhawa/Downloads/B2A/aws-infrastructure
terraform destroy -auto-approve
```

This will delete:
- All 6 EC2 instances
- VPC and networking
- Security groups
- All associated resources

**Estimated cost savings:** ~$0.50-1.00/hour when destroyed

---

## 📞 SUPPORT

If you encounter issues:
1. Check the troubleshooting section above
2. Review logs: `kubectl logs -n monitoring <pod-name>`
3. Verify all pods are running: `kubectl get pods -n monitoring`

---

## ✨ SUMMARY

**You now have:**
- ✅ 3-node Kubernetes cluster with kubeadm
- ✅ 3-node Docker Swarm cluster (for comparison)
- ✅ Complete monitoring stack (Grafana + Prometheus)
- ✅ Real-time metrics collection from all nodes
- ✅ Sample workload (nginx) for testing
- ✅ Web-accessible dashboards for visualization
- ✅ Everything ready for PhD research documentation

**Access your dashboard now:** http://52.66.203.212:30300  
**Login:** admin / admin

**Good luck with your PhD research!** 🎓📊🚀

---

**Created:** April 4, 2026  
**Infrastructure:** AWS ap-south-1  
**Monitoring:** Grafana + Prometheus  
**Status:** ✅ OPERATIONAL
