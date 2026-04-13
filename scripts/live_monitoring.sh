#!/bin/bash

###############################################################################
# Live Karpenter Monitoring Script for PhD Documentation Screenshots
# This script provides real-time views of Karpenter in action
###############################################################################

# Color codes for better visualization
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Clear screen for clean screenshots
clear

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       PhD Research: Live Karpenter Memory-Aware Bin-Packing Monitor       ║${NC}"
echo -e "${CYAN}║                    Kubernetes vs Docker Swarm Study                        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to display section headers
section_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════${NC}"
}

# Main monitoring loop
while true; do
    clear

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       PhD Research: Live Karpenter Memory-Aware Bin-Packing Monitor       ║${NC}"
    echo -e "${CYAN}║                 $(date '+%Y-%m-%d %H:%M:%S') | Region: ap-south-1                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════╝${NC}"

    # Section 1: Cluster Nodes Status
    section_header "📊 CLUSTER NODES STATUS (KMAB Phase 3: Provisioning)"
    kubectl get nodes -o wide --no-headers | while read line; do
        node_name=$(echo $line | awk '{print $1}')
        status=$(echo $line | awk '{print $2}')
        role=$(echo $line | awk '{print $3}')
        age=$(echo $line | awk '{print $4}')

        if [[ "$status" == "Ready" ]]; then
            echo -e "${GREEN}✓${NC} $node_name | Status: ${GREEN}$status${NC} | Role: $role | Age: $age"
        else
            echo -e "${RED}✗${NC} $node_name | Status: ${RED}$status${NC} | Role: $role | Age: $age"
        fi
    done

    # Section 2: Karpenter Controller Status
    section_header "🚀 KARPENTER CONTROLLER STATUS"
    kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter --no-headers | while read line; do
        pod=$(echo $line | awk '{print $1}')
        ready=$(echo $line | awk '{print $2}')
        status=$(echo $line | awk '{print $3}')
        restarts=$(echo $line | awk '{print $4}')

        if [[ "$status" == "Running" ]]; then
            echo -e "${GREEN}✓${NC} $pod | Ready: ${GREEN}$ready${NC} | Status: ${GREEN}$status${NC} | Restarts: $restarts"
        else
            echo -e "${YELLOW}⏳${NC} $pod | Ready: $ready | Status: ${YELLOW}$status${NC} | Restarts: $restarts"
        fi
    done

    # Section 3: Node Resource Usage (KMAB Phase 2: Bin-packing)
    section_header "💾 NODE RESOURCE USAGE (Memory Waste Analysis)"
    echo -e "${WHITE}Node Name          CPU Usage    Memory Usage    CPU %      Memory %${NC}"
    echo "────────────────────────────────────────────────────────────────────────"
    kubectl top nodes --no-headers 2>/dev/null | while read line; do
        node=$(echo $line | awk '{print $1}')
        cpu=$(echo $line | awk '{print $2}')
        cpu_pct=$(echo $line | awk '{print $3}')
        mem=$(echo $line | awk '{print $4}')
        mem_pct=$(echo $line | awk '{print $5}')

        # Color code based on usage
        if [[ ${cpu_pct%\%} -gt 80 ]]; then
            cpu_color=$RED
        elif [[ ${cpu_pct%\%} -gt 60 ]]; then
            cpu_color=$YELLOW
        else
            cpu_color=$GREEN
        fi

        if [[ ${mem_pct%\%} -gt 80 ]]; then
            mem_color=$RED
        elif [[ ${mem_pct%\%} -gt 60 ]]; then
            mem_color=$YELLOW
        else
            mem_color=$GREEN
        fi

        printf "%-18s ${cpu_color}%-12s${NC} ${mem_color}%-15s${NC} ${cpu_color}%-10s${NC} ${mem_color}%-10s${NC}\n" \
            "$node" "$cpu" "$mem" "$cpu_pct" "$mem_pct"
    done || echo -e "${YELLOW}Metrics not available yet. Waiting for Metrics Server...${NC}"

    # Section 4: Application Pods (KMAB Phase 4: Scaling)
    section_header "📦 APPLICATION PODS STATUS (HPA Autoscaling)"
    echo -e "${WHITE}Pod Name                    Status      Restarts  Node                CPU      Memory${NC}"
    echo "────────────────────────────────────────────────────────────────────────────────────"
    kubectl get pods -o wide --no-headers 2>/dev/null | grep -v "kube-system\|calico\|coredns" | while read line; do
        pod=$(echo $line | awk '{print $1}')
        status=$(echo $line | awk '{print $3}')
        restarts=$(echo $line | awk '{print $4}')
        node=$(echo $line | awk '{print $7}')

        # Get resource usage
        metrics=$(kubectl top pod $pod --no-headers 2>/dev/null)
        cpu=$(echo $metrics | awk '{print $2}' 2>/dev/null || echo "N/A")
        mem=$(echo $metrics | awk '{print $3}' 2>/dev/null || echo "N/A")

        if [[ "$status" == "Running" ]]; then
            printf "${GREEN}%-27s${NC} ${GREEN}%-11s${NC} %-9s %-19s %-8s %-8s\n" "$pod" "$status" "$restarts" "$node" "$cpu" "$mem"
        else
            printf "${YELLOW}%-27s${NC} ${YELLOW}%-11s${NC} %-9s %-19s %-8s %-8s\n" "$pod" "$status" "$restarts" "$node" "$cpu" "$mem"
        fi
    done

    # Section 5: Horizontal Pod Autoscaler Status
    section_header "⚡ HORIZONTAL POD AUTOSCALER (HPA) - Phase 4"
    kubectl get hpa --no-headers 2>/dev/null | while read line; do
        name=$(echo $line | awk '{print $1}')
        ref=$(echo $line | awk '{print $2}')
        targets=$(echo $line | awk '{print $3}')
        min=$(echo $line | awk '{print $4}')
        max=$(echo $line | awk '{print $5}')
        replicas=$(echo $line | awk '{print $6}')
        age=$(echo $line | awk '{print $7}')

        echo -e "${CYAN}HPA:${NC} $name"
        echo -e "  Target: $ref | Metrics: ${YELLOW}$targets${NC}"
        echo -e "  Replicas: ${GREEN}$replicas${NC} (min: $min, max: $max) | Age: $age"
    done || echo -e "${YELLOW}No HPA configured yet${NC}"

    # Section 6: Karpenter NodePools (KMAB Configuration)
    section_header "🎯 KARPENTER NODEPOOLS (KMAB Configuration)"
    kubectl get nodepools --no-headers 2>/dev/null | while read line; do
        name=$(echo $line | awk '{print $1}')
        echo -e "${MAGENTA}NodePool:${NC} $name"
        kubectl describe nodepool $name 2>/dev/null | grep -A 5 "Limits:\|Disruption:"
    done || echo -e "${YELLOW}No NodePools configured yet${NC}"

    # Section 7: Recent Karpenter Events (KMAB Phase 5: Consolidation)
    section_header "📋 RECENT KARPENTER EVENTS (Last 10)"
    kubectl get events -n kube-system --sort-by='.lastTimestamp' 2>/dev/null | \
        grep -i "karpenter\|provisioner\|node" | tail -10 | \
        awk '{printf "%-8s %-25s %-60s\n", $1, $5, substr($0, index($0,$6))}'

    # Section 8: Memory Waste Calculation
    section_header "🧮 MEMORY WASTE ANALYSIS (Research Objective 2)"
    echo -e "${WHITE}Calculating memory efficiency...${NC}"

    total_mem=0
    used_mem=0
    node_count=0

    while read line; do
        mem=$(echo $line | awk '{print $4}')
        mem_value=$(echo $mem | sed 's/Mi//g')

        if [[ -n "$mem_value" ]] && [[ "$mem_value" =~ ^[0-9]+$ ]]; then
            used_mem=$((used_mem + mem_value))
            node_count=$((node_count + 1))
            # Assume t2.micro has 1GB = 1024Mi total
            total_mem=$((total_mem + 1024))
        fi
    done < <(kubectl top nodes --no-headers 2>/dev/null)

    if [[ $node_count -gt 0 ]]; then
        waste=$((total_mem - used_mem))
        efficiency=$((used_mem * 100 / total_mem))
        waste_pct=$((100 - efficiency))

        echo -e "  Total Memory:      ${CYAN}${total_mem}Mi${NC}"
        echo -e "  Used Memory:       ${GREEN}${used_mem}Mi${NC}"
        echo -e "  Wasted Memory:     ${RED}${waste}Mi${NC}"
        echo -e "  Memory Efficiency: ${GREEN}${efficiency}%${NC}"
        echo -e "  Memory Waste:      ${RED}${waste_pct}%${NC}"
    else
        echo -e "${YELLOW}Metrics not available yet${NC}"
    fi

    # Footer
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Press Ctrl+C to stop monitoring | Refresh every 5 seconds${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════${NC}"

    sleep 5
done
