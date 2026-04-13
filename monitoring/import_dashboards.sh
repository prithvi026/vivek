#!/bin/bash

###############################################################################
# Import Custom Grafana Dashboards for PhD Research
# Automated dashboard provisioning
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              Importing PhD Research Dashboards to Grafana                  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get Grafana pod
GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')

if [ -z "$GRAFANA_POD" ]; then
    echo -e "${YELLOW}Error: Grafana pod not found. Please run install_monitoring_stack.sh first.${NC}"
    exit 1
fi

echo -e "${BLUE}Found Grafana pod: $GRAFANA_POD${NC}"

# Get Kubernetes control plane IP
cd /c/Users/prithivikachhawa/Downloads/B2A/aws-infrastructure
K8S_CONTROL=$(terraform output -raw k8s_control_plane_public_ip)

# Wait for Grafana API to be ready
echo -e "${YELLOW}Waiting for Grafana API...${NC}"
until kubectl exec -n monitoring $GRAFANA_POD -- curl -s http://localhost:3000/api/health | grep -q "ok"; do
    echo -n "."
    sleep 2
done
echo ""
echo -e "${GREEN}✓ Grafana API is ready${NC}"

# Function to import dashboard
import_dashboard() {
    local dashboard_file=$1
    local dashboard_name=$(basename $dashboard_file .json)

    echo -e "${BLUE}Importing dashboard: $dashboard_name...${NC}"

    # Copy dashboard JSON to Grafana pod
    kubectl cp $dashboard_file monitoring/$GRAFANA_POD:/tmp/dashboard.json

    # Import via API
    kubectl exec -n monitoring $GRAFANA_POD -- curl -X POST \
        -H "Content-Type: application/json" \
        -d @/tmp/dashboard.json \
        http://admin:admin@localhost:3000/api/dashboards/db

    echo -e "${GREEN}✓ Imported: $dashboard_name${NC}"
}

# Import all dashboards
cd /c/Users/prithivikachhawa/Downloads/B2A/monitoring/dashboards

echo ""
echo -e "${CYAN}Importing dashboards...${NC}"

if [ -f "objective3-comparison.json" ]; then
    import_dashboard "objective3-comparison.json"
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                     Dashboards Imported Successfully!                      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}Access Grafana:${NC}"
echo "  URL: http://$K8S_CONTROL:30300"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo -e "${GREEN}Available Dashboards:${NC}"
echo "  1. PhD Research - Objective 3: Kubernetes vs Docker Swarm Comparison"
echo ""
echo -e "${YELLOW}Tips for taking screenshots:${NC}"
echo "  1. Set time range to 'Last 30 minutes' for live demo"
echo "  2. Use 'Refresh' every 5s for real-time updates"
echo "  3. Click 'Full screen' (F11) for clean screenshots"
echo "  4. Use 'Theme: Light' for better print quality"
echo ""
