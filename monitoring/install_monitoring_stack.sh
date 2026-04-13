#!/bin/bash

###############################################################################
# Install Grafana + Prometheus Monitoring Stack
# For PhD Research: Kubernetes vs Docker Swarm Comparison
###############################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         Installing Grafana + Prometheus Monitoring Stack                  ║${NC}"
echo -e "${CYAN}║              PhD Research Documentation Dashboard                          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Install Prometheus Operator using Helm
echo -e "${BLUE}Step 1: Installing Prometheus Operator...${NC}"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (includes Prometheus, Grafana, and exporters)
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi \
  --set prometheus.prometheusSpec.resources.limits.memory=1Gi \
  --set grafana.adminPassword=admin \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30300 \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30900 \
  --wait

echo -e "${GREEN}✓ Prometheus Operator installed${NC}"

# Step 2: Wait for pods to be ready
echo -e "${BLUE}Step 2: Waiting for monitoring stack to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s

echo -e "${GREEN}✓ Monitoring stack is ready${NC}"

# Step 3: Install Node Exporter on Docker Swarm nodes for comparison
echo -e "${BLUE}Step 3: Setting up Docker Swarm monitoring...${NC}"

# Get Docker node IPs from terraform output
cd /c/Users/prithivikachhawa/Downloads/B2A/aws-infrastructure

DOCKER_MANAGER=$(terraform output -raw docker_manager_public_ip)
DOCKER_WORKER_1=$(terraform output -raw docker_worker_1_public_ip)
DOCKER_WORKER_2=$(terraform output -raw docker_worker_2_public_ip)

# Install node_exporter on Docker Swarm nodes
for NODE_IP in $DOCKER_MANAGER $DOCKER_WORKER_1 $DOCKER_WORKER_2; do
    echo -e "${YELLOW}Installing node_exporter on $NODE_IP...${NC}"

    ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@$NODE_IP << 'ENDSSH'
# Download and install node_exporter
cd /tmp
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
tar xzf node_exporter-1.8.2.linux-amd64.tar.gz
sudo mv node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-*

# Create systemd service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Start service
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
echo "Node exporter installed and started"
ENDSSH

    echo -e "${GREEN}✓ Node exporter installed on $NODE_IP${NC}"
done

# Step 4: Configure Prometheus to scrape Docker Swarm nodes
echo -e "${BLUE}Step 4: Configuring Prometheus for Docker Swarm monitoring...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-docker-swarm-config
  namespace: monitoring
data:
  docker-swarm.yml: |
    - job_name: 'docker-swarm-nodes'
      static_configs:
        - targets:
          - '$DOCKER_MANAGER:9100'
          - '$DOCKER_WORKER_1:9100'
          - '$DOCKER_WORKER_2:9100'
          labels:
            cluster: 'docker-swarm'
            research: 'phd-objective-3'
EOF

echo -e "${GREEN}✓ Prometheus configured${NC}"

# Step 5: Get access information
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    Monitoring Stack Installed!                             ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

K8S_CONTROL=$(terraform output -raw k8s_control_plane_public_ip)

echo -e "${GREEN}Access Information:${NC}"
echo ""
echo -e "${BLUE}Grafana Dashboard:${NC}"
echo "  URL: http://$K8S_CONTROL:30300"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo -e "${BLUE}Prometheus:${NC}"
echo "  URL: http://$K8S_CONTROL:30900"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Access Grafana in your browser"
echo "  2. Import the comparison dashboards (run import_dashboards.sh)"
echo "  3. Take screenshots for your thesis!"
echo ""
echo -e "${CYAN}Dashboard Import Command:${NC}"
echo "  ./monitoring/import_dashboards.sh"
echo ""
