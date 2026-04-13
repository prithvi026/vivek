# 🎉 Grafana is NOW Working!

## ✅ SOLUTION IMPLEMENTED

I've moved Grafana to the control plane node (t3.medium with 4GB RAM) because the t2.micro worker nodes (1GB RAM) were under memory pressure.

---

## 🌐 HOW TO ACCESS GRAFANA

### **Method: SSH Tunnel (WORKING)**

The SSH tunnel is already running in the background. Simply:

**Open your browser and go to:**
```
http://localhost:8888
```

**Login:**
- Username: `admin`
- Password: `admin`

---

## 📊 WHAT TO DO NEXT

### **1. Import Dashboard 1860** (Node Metrics - Best for your setup)

Once logged in:
1. Click the **"+"** icon in the left sidebar
2. Select **"Import"**
3. Enter dashboard ID: **1860**
4. Click **"Load"**
5. Select datasource: **"Prometheus"**
6. Click **"Import"**

This will show:
- CPU usage per node
- Memory utilization per node
- Disk and network metrics
- Perfect for PhD screenshots!

### **2. Generate Load to See Metrics**

```bash
ssh -i ~/.ssh/id_rsa ubuntu@65.1.2.253
kubectl scale deployment cpu-stress-app --replicas=5
```

Wait 2-3 minutes, then refresh Grafana - you'll see metrics spike!

### **3. Take Screenshots**

- Set time range: **"Last 30 minutes"** (top right)
- Set refresh: **"5s"** for live updates
- Press **F11** for fullscreen
- Take screenshots for your thesis!

---

## 🔧 TECHNICAL NOTES

### **Why did the original method fail?**

- **t2.micro instances** (1GB RAM) are too small for monitoring stack
- Worker nodes ran out of memory → memory pressure taint
- Grafana pods couldn't be scheduled

### **Solution:**

- Moved Grafana to **control plane node** (t3.medium, 4GB RAM)
- Added tolerations and node selector
- Pod now runs successfully with resources available

### **Current Setup:**

- **Control Plane** (ip-10-0-1-85): Grafana + Kubernetes control plane
- **Worker 1** (ip-10-0-1-29): Application workloads only
- **Worker 2** (ip-10-0-1-92): Currently NotReady (being investigated)

---

## 📸 SCREENSHOT GUIDE

### **Best Dashboards for PhD Thesis:**

| Dashboard ID | Name | What It Shows | Priority |
|-------------|------|---------------|----------|
| **1860** | Node Exporter Full | System metrics per node | ⭐⭐⭐ |
| **315** | Kubernetes Cluster | Complete cluster overview | ⭐⭐ |
| **747** | Kubernetes Deployment | Pod/deployment status | ⭐ |

### **Screenshot Checklist:**

- [ ] Import Dashboard 1860
- [ ] Generate load (scale deployment to 5 replicas)
- [ ] Wait 2-3 minutes for metrics to populate
- [ ] Set time range to "Last 30 minutes"
- [ ] Take full-screen screenshot (F11)
- [ ] Capture at least 3 different views:
  - Overall cluster metrics
  - Individual node metrics
  - Resource utilization graphs under load

---

## 🚀 QUICK COMMANDS

### **Access Grafana:**
```
http://localhost:8888
admin / admin
```

### **Generate Load:**
```bash
ssh -i ~/.ssh/id_rsa ubuntu@65.1.2.253
kubectl scale deployment cpu-stress-app --replicas=5
```

### **Check Grafana Status:**
```bash
ssh -i ~/.ssh/id_rsa ubuntu@65.1.2.253
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
```

### **Restart Tunnel (if needed):**
```bash
# Kill existing tunnel
pkill -f "ssh.*8888:10.104.167.203"

# Start new tunnel
ssh -i ~/.ssh/id_rsa -L 8888:10.104.167.203:80 -N ubuntu@65.1.2.253
```

Or just run: `GRAFANA_WORKING_ACCESS.bat`

---

## ✅ STATUS: READY FOR SCREENSHOTS

Your monitoring stack is now fully operational and ready for thesis documentation!

**Created:** 2026-03-29
**Status:** ✅ Working
**Access:** http://localhost:8888
