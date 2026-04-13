# 🌐 Access Grafana Dashboard NOW!

## Your Grafana is Installing...

**Installation Status**: ⏳ In progress (takes 5-7 minutes)

---

## 📊 **Access Information**

### **Grafana Dashboard**
```
URL:      http://65.1.2.253:30300
Username: admin
Password: admin
```

### **Prometheus (Metrics)**
```
URL: http://65.1.2.253:30900
```

---

## 🔥 **What to Do NOW**

### **Step 1: Wait for Installation** (5 minutes)

While Grafana installs, you can monitor progress:

```bash
# Check installation status
ssh -i ~/.ssh/id_rsa ubuntu@65.1.2.253
kubectl get pods -n monitoring --watch
```

You'll see pods starting like:
- `monitoring-grafana-xxx` - Grafana dashboard
- `prometheus-monitoring-kube-prometheus-prometheus-0` - Metrics database
- `monitoring-kube-prometheus-operator-xxx` - Operator

**Wait for all to show "Running" status**

---

### **Step 2: Access Grafana in Browser**

Once installation completes (~5 minutes), open your browser:

1. **Open this URL**: http://65.1.2.253:30300

2. **Login Screen** will appear:
   - Enter username: `admin`
   - Enter password: `admin`

3. **Welcome Screen** - You're in! 🎉

---

### **Step 3: Import a Dashboard**

Once logged in:

1. **Click** the `+` icon (left sidebar)
2. **Select** "Import"
3. **Enter Dashboard ID**: `315` (Kubernetes Cluster Monitoring)
4. **Click** "Load"
5. **Select Datasource**: "Prometheus"
6. **Click** "Import"

**Boom! You'll see beautiful metrics!** 📊

---

### **Step 4: Generate Load for Demo**

Open a terminal and run:

```bash
ssh -i ~/.ssh/id_rsa ubuntu@65.1.2.253
kubectl scale deployment cpu-stress-app --replicas=5
```

**Wait 2-3 minutes**, then refresh Grafana - you'll see metrics spike! 📈

---

## 📸 **Taking Your First Screenshot**

1. **In Grafana**, click on the dashboard you imported
2. **Set time range** to "Last 30 minutes" (top right)
3. **Set refresh** to "5s" (next to time range)
4. **Press F11** for fullscreen
5. **Wait 10 seconds** for data to load
6. **Take screenshot**: Windows Key + Shift + S

**Perfect for your thesis!** 🎓

---

## 🎯 **Best Dashboards to Import**

| Dashboard ID | Name | What It Shows |
|-------------|------|---------------|
| **315** | Kubernetes Cluster Monitoring | Complete cluster overview ⭐ |
| **1860** | Node Exporter Full | Detailed node metrics ⭐ |
| **747** | Kubernetes Deployment | Deployment status |
| **6417** | Kubernetes Cluster (Prometheus) | Alternative cluster view |

**Import each one** using the same steps above!

---

## 🔍 **What You'll See in Grafana**

### **Dashboard Features:**

```
┌─────────────────────────────────────────────────────────┐
│  Kubernetes Cluster Monitoring                          │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ CPU Usage    │  │ Memory Usage │  │ Pod Count    │  │
│  │ ▓▓▓▓░░ 65%   │  │ ▓▓▓▓▓░ 82%  │  │     12       │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │ CPU Usage Over Time                                 │ │
│  │     100% ┤                                          │ │
│  │      80% ┤     ╱╲                                   │ │
│  │      60% ┤    ╱  ╲  ╱╲                             │ │
│  │      40% ┤ ╱╲╱    ╲╱  ╲╱╲                          │ │
│  │      20% ┤╱                ╲                        │ │
│  │       0% ┴─────────────────────────────────────    │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Memory Usage Over Time                              │ │
│  │  (Beautiful time-series graphs here)                │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

**Professional, publication-quality visualizations!** ✨

---

## ⏱️ **Installation Timeline**

| Time | What's Happening |
|------|------------------|
| 0 min | Installation started ✅ |
| 2 min | Downloading container images... |
| 4 min | Starting Prometheus... |
| 5 min | Starting Grafana... |
| 6 min | Configuring datasources... |
| 7 min | **Ready to access!** 🎉 |

**Current Status**: Check with the command below

---

## 🔧 **Check Installation Status**

Run this command to see progress:

```bash
ssh -i ~/.ssh/id_rsa ubuntu@65.1.2.253 "kubectl get pods -n monitoring"
```

**Look for:**
```
NAME                                                   READY   STATUS
monitoring-grafana-xxx-xxx                            3/3     Running  ✅
prometheus-monitoring-kube-prometheus-prometheus-0    2/2     Running  ✅
monitoring-kube-prometheus-operator-xxx-xxx           1/1     Running  ✅
```

**When all show "Running" = Ready to access!** 🎉

---

## 🎓 **Why This is Perfect for Your PhD**

✅ **Professional Visualizations** - Better than terminal screenshots
✅ **Real-Time Metrics** - Live demonstration capability
✅ **Historical Data** - Shows trends over time
✅ **Comparison Views** - Side-by-side K8s vs Docker Swarm
✅ **Exportable** - Save as PNG, PDF, or CSV data
✅ **Customizable** - Add annotations, change themes
✅ **Publication Quality** - Perfect for thesis figures

**Your examiners will be impressed!** 🎓✨

---

## 💡 **Pro Tip**

While waiting for installation, you can:

1. **Read** the screenshot guide
2. **Plan** which metrics you want to capture
3. **Prepare** your load testing scenarios
4. **Open** your browser and navigate to the URL (bookmark it!)

**When installation completes, you'll be ready to go immediately!** 🚀

---

## 📞 **Need Help?**

### **Installation seems stuck?**
```bash
# Check logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=50

# Check events
kubectl get events -n monitoring --sort-by='.lastTimestamp' | tail -20
```

### **Can't access Grafana?**
```bash
# Verify service is running
kubectl get svc -n monitoring | grep grafana

# Port forward as alternative
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# Then access: http://localhost:3000
```

---

## ⏰ **Estimated Time Remaining**

If installation started just now:
- **Current time**: Installation in progress
- **Estimated completion**: 5-7 minutes from start
- **Check status**: Every 1-2 minutes

**Be patient - it's worth the wait for beautiful dashboards!** ⏳

---

**Once you see this screen, you're ready:**

```
┌──────────────────────────────────────────┐
│                                          │
│           Welcome to Grafana             │
│                                          │
│   Username: _______________              │
│                                          │
│   Password: _______________              │
│                                          │
│         [ Sign In ]                      │
│                                          │
└──────────────────────────────────────────┘
```

**Enter: admin / admin and you're in!** 🎉

---

**Next**: Open http://65.1.2.253:30300 in your browser!
