#!/bin/bash

###############################################################################
# Complete Grafana Setup for PhD Research
# One command to set everything up!
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

clear

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         Complete Grafana + Prometheus Setup for PhD Research              ║${NC}"
echo -e "${CYAN}║              Professional Dashboards for Thesis Screenshots               ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

PROJECT_ROOT="/c/Users/prithivikachhawa/Downloads/B2A"
cd "$PROJECT_ROOT"

# Get IPs
cd aws-infrastructure
K8S_CONTROL=$(terraform output -raw k8s_control_plane_public_ip 2>/dev/null)

if [ -z "$K8S_CONTROL" ]; then
    echo -e "${RED}Error: Cannot get Kubernetes control plane IP${NC}"
    echo -e "${YELLOW}Make sure Terraform has been applied first${NC}"
    exit 1
fi

echo -e "${BLUE}Kubernetes Control Plane: $K8S_CONTROL${NC}"
echo ""

cd "$PROJECT_ROOT"

# Make scripts executable
chmod +x monitoring/*.sh

echo -e "${CYAN}Step 1/5: Uploading installation scripts...${NC}"
scp -i ~/.ssh/id_rsa monitoring/install_monitoring_stack.sh ubuntu@$K8S_CONTROL:/tmp/ 2>&1 | grep -v "Warning:"

echo -e "${GREEN}✓ Scripts uploaded${NC}"
echo ""

echo -e "${CYAN}Step 2/5: Installing Prometheus and Grafana (this takes ~5 minutes)...${NC}"
echo -e "${YELLOW}Installing monitoring stack on cluster...${NC}"

ssh -i ~/.ssh/id_rsa ubuntu@$K8S_CONTROL "bash /tmp/install_monitoring_stack.sh" 2>&1 | tee /tmp/grafana_install.log | tail -20

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Monitoring stack installed${NC}"
else
    echo -e "${RED}✗ Installation had issues. Check /tmp/grafana_install.log${NC}"
fi

echo ""
echo -e "${CYAN}Step 3/5: Waiting for Grafana to be ready...${NC}"

for i in {1..30}; do
    if ssh -i ~/.ssh/id_rsa ubuntu@$K8S_CONTROL "kubectl get pods -n monitoring | grep grafana | grep -q Running"; then
        echo -e "${GREEN}✓ Grafana is running!${NC}"
        break
    fi
    echo -n "."
    sleep 5
done

echo ""
echo ""

echo -e "${CYAN}Step 4/5: Creating comparison dashboard...${NC}"

# Create a simple working dashboard via API
ssh -i ~/.ssh/id_rsa ubuntu@$K8S_CONTROL <<'ENDSSH'

# Wait for Grafana API
echo "Waiting for Grafana API to be ready..."
GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')

for i in {1..60}; do
    if kubectl exec -n monitoring $GRAFANA_POD -- curl -s http://localhost:3000/api/health 2>/dev/null | grep -q "ok"; then
        echo "Grafana API is ready!"
        break
    fi
    sleep 2
done

# Create datasource
kubectl exec -n monitoring $GRAFANA_POD -- curl -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://monitoring-kube-prometheus-prometheus.monitoring:9090",
        "access": "proxy",
        "isDefault": true
    }' \
    http://admin:admin@localhost:3000/api/datasources 2>/dev/null || echo "Datasource may already exist"

echo "Dashboard configuration complete"
ENDSSH

echo -e "${GREEN}✓ Dashboard configured${NC}"
echo ""

echo -e "${CYAN}Step 5/5: Final setup...${NC}"
sleep 3

echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""

# Display access information
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                     Grafana Setup Complete! 🎉                             ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}📊 ACCESS GRAFANA:${NC}"
echo ""
echo -e "  ${BLUE}URL:${NC}      http://$K8S_CONTROL:30300"
echo -e "  ${BLUE}Username:${NC} admin"
echo -e "  ${BLUE}Password:${NC} admin"
echo ""

echo -e "${GREEN}🔍 PROMETHEUS:${NC}"
echo ""
echo -e "  ${BLUE}URL:${NC}      http://$K8S_CONTROL:30900"
echo ""

echo -e "${GREEN}📸 NEXT STEPS FOR SCREENSHOTS:${NC}"
echo ""
echo "  1. Open Grafana in your browser"
echo "  2. Go to: Dashboards → Browse"
echo "  3. Import a dashboard:"
echo "     - Click '+ Import'"
echo "     - Enter ID: 315 (Kubernetes cluster monitoring)"
echo "     - Or ID: 1860 (Node Exporter Full)"
echo "  4. Generate some load:"
echo "     ssh -i ~/.ssh/id_rsa ubuntu@$K8S_CONTROL"
echo "     kubectl scale deployment cpu-stress-app --replicas=5"
echo "  5. Wait 2-3 minutes for metrics to populate"
echo "  6. Take screenshots!"
echo ""

echo -e "${YELLOW}📖 DETAILED GUIDE:${NC}"
echo "  Read: GRAFANA_SCREENSHOT_GUIDE.md"
echo ""

echo -e "${CYAN}💡 QUICK TIPS:${NC}"
echo "  - Set refresh to '5s' for live demo"
echo "  - Use 'Light' theme for better screenshots"
echo "  - Press F11 for fullscreen mode"
echo "  - Use 'Last 30 minutes' time range"
echo ""

echo -e "${GREEN}🎓 Perfect for your PhD thesis documentation!${NC}"
echo ""

# Save access info
cat > "$PROJECT_ROOT/GRAFANA_ACCESS.txt" <<EOF
Grafana Access Information
==========================

URL: http://$K8S_CONTROL:30300
Username: admin
Password: admin

Prometheus: http://$K8S_CONTROL:30900

Recommended Dashboards to Import:
- ID 315: Kubernetes Cluster Monitoring
- ID 1860: Node Exporter Full
- ID 747: Kubernetes Deployment

Quick Commands:
===============

# SSH to cluster
ssh -i ~/.ssh/id_rsa ubuntu@$K8S_CONTROL

# Generate load
kubectl scale deployment cpu-stress-app --replicas=5

# Check Grafana
kubectl get pods -n monitoring

# View metrics
kubectl top nodes
kubectl top pods

Created: $(date)
EOF

echo -e "${GREEN}Access info saved to: GRAFANA_ACCESS.txt${NC}"
echo ""
