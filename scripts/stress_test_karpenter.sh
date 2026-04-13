#!/bin/bash

###############################################################################
# Stress Test Script to Demonstrate Karpenter Autoscaling
# This will trigger KMAB phases for documentation screenshots
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           Karpenter Stress Test - PhD Research Demonstration              ║${NC}"
echo -e "${CYAN}║              This will trigger KMAB phases for screenshots                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Test scenarios
echo -e "${BLUE}Available Test Scenarios:${NC}"
echo "  1. Light Load   - 2 pods  (demonstrate baseline)"
echo "  2. Medium Load  - 5 pods  (trigger horizontal scaling)"
echo "  3. Heavy Load   - 10 pods (trigger node provisioning)"
echo "  4. Extreme Load - 20 pods (demonstrate consolidation)"
echo "  5. Variable Load - Cycling (show adaptive behavior)"
echo ""

read -p "Select scenario (1-5): " scenario

case $scenario in
    1)
        REPLICAS=2
        SCENARIO_NAME="Light Load"
        ;;
    2)
        REPLICAS=5
        SCENARIO_NAME="Medium Load"
        ;;
    3)
        REPLICAS=10
        SCENARIO_NAME="Heavy Load"
        ;;
    4)
        REPLICAS=20
        SCENARIO_NAME="Extreme Load"
        ;;
    5)
        SCENARIO_NAME="Variable Load"
        echo -e "${YELLOW}Variable load test will cycle through different replica counts${NC}"
        ;;
    *)
        echo -e "${RED}Invalid selection${NC}"
        exit 1
        ;;
esac

# Create stress test deployment
create_stress_deployment() {
    local replicas=$1

    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-test-app
  labels:
    app: stress-test
    research: phd-karpenter-demo
spec:
  replicas: $replicas
  selector:
    matchLabels:
      app: stress-test
  template:
    metadata:
      labels:
        app: stress-test
        research: phd-objective-2
    spec:
      containers:
      - name: stress
        image: polinux/stress
        resources:
          requests:
            cpu: "250m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        command: ["stress"]
        args:
          - "--cpu"
          - "1"
          - "--io"
          - "1"
          - "--vm"
          - "1"
          - "--vm-bytes"
          - "128M"
          - "--timeout"
          - "600s"
          - "--verbose"
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: stress-test-hpa
  labels:
    research: phd-karpenter-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: stress-test-app
  minReplicas: 2
  maxReplicas: 25
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
      - type: Pods
        value: 4
        periodSeconds: 30
      - type: Percent
        value: 100
        periodSeconds: 30
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 60
      policies:
      - type: Pods
        value: 2
        periodSeconds: 30
      selectPolicy: Min
EOF
}

# Variable load test
variable_load_test() {
    echo -e "${CYAN}Starting Variable Load Test...${NC}"

    # Start with light load
    echo -e "${YELLOW}Phase 1: Light Load (2 replicas) - 2 minutes${NC}"
    create_stress_deployment 2
    sleep 120

    # Increase to medium
    echo -e "${YELLOW}Phase 2: Medium Load (8 replicas) - 3 minutes${NC}"
    kubectl scale deployment stress-test-app --replicas=8
    sleep 180

    # Peak load
    echo -e "${YELLOW}Phase 3: Peak Load (15 replicas) - 3 minutes${NC}"
    kubectl scale deployment stress-test-app --replicas=15
    sleep 180

    # Scale down
    echo -e "${YELLOW}Phase 4: Scale Down (5 replicas) - 2 minutes${NC}"
    kubectl scale deployment stress-test-app --replicas=5
    sleep 120

    # Minimal load
    echo -e "${YELLOW}Phase 5: Minimal Load (2 replicas) - Observing consolidation${NC}"
    kubectl scale deployment stress-test-app --replicas=2
    sleep 120

    echo -e "${GREEN}Variable load test complete!${NC}"
}

# Main execution
echo -e "${CYAN}Starting $SCENARIO_NAME test...${NC}"
echo ""

if [[ $scenario == "5" ]]; then
    variable_load_test
else
    echo -e "${YELLOW}Deploying stress test with $REPLICAS replicas...${NC}"
    create_stress_deployment $REPLICAS

    echo ""
    echo -e "${GREEN}✓${NC} Stress test deployment created!"
    echo ""
    echo -e "${BLUE}What to watch for in your monitoring:${NC}"
    echo "  📊 Phase 1: Observation - Karpenter detecting pending pods"
    echo "  🧮 Phase 2: Bin-packing - Calculating optimal instance types"
    echo "  🚀 Phase 3: Provisioning - Launching new EC2 instances"
    echo "  ⚡ Phase 4: Scaling - HPA adjusting replica count"
    echo "  🔄 Phase 5: Consolidation - Removing underutilized nodes"
    echo ""
    echo -e "${CYAN}Monitor progress with:${NC}"
    echo "  watch -n 2 'kubectl get nodes'"
    echo "  watch -n 2 'kubectl get pods -o wide'"
    echo "  watch -n 2 'kubectl top nodes'"
    echo "  kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f"
    echo ""
    echo -e "${YELLOW}Or use the live monitoring dashboard:${NC}"
    echo "  ./scripts/live_monitoring.sh"
    echo ""

    # Wait and monitor
    echo -e "${CYAN}Monitoring for 5 minutes...${NC}"
    for i in {1..30}; do
        echo -n "."
        sleep 10
    done
    echo ""

    # Show final status
    echo -e "${GREEN}Test running. Check status:${NC}"
    kubectl get pods -l app=stress-test -o wide
    echo ""
    kubectl get nodes
    echo ""
    kubectl top nodes
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                        Stress Test Active                                  ║${NC}"
echo -e "${CYAN}║         Perfect time to take screenshots for your documentation!          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}To cleanup:${NC} kubectl delete deployment stress-test-app"
echo -e "${YELLOW}To cleanup HPA:${NC} kubectl delete hpa stress-test-hpa"
