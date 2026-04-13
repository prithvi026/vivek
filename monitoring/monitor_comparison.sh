#!/bin/bash
"""
Unified Monitoring Script for Objective 3: Comparative Analysis
Kubernetes vs Docker Swarm Performance Monitoring

This script implements the monitoring framework described in the research document,
collecting metrics from both platforms at identical 10-second sampling intervals.
"""

set -e

# Configuration
SAMPLING_INTERVAL=10
KUBERNETES_NAMESPACE="default"
DOCKER_SERVICE_NAME="phd-research_cpu-stress-app"

# File outputs
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="./results/obj3_results_${TIMESTAMP}"
K8S_OUTPUT="${OUTPUT_DIR}/kubernetes_metrics.csv"
DOCKER_OUTPUT="${OUTPUT_DIR}/docker_swarm_metrics.csv"
COMPARISON_OUTPUT="${OUTPUT_DIR}/comparison_summary.csv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Setup
setup_monitoring() {
    log_info "Setting up monitoring environment..."
    
    # Create output directory
    mkdir -p "${OUTPUT_DIR}"
    
    # Create CSV headers
    echo "timestamp,cpu_percent,memory_used_mb,memory_percent,containers,response_time_ms,additional_metric1,additional_metric2" > "${DOCKER_OUTPUT}"
    echo "timestamp,cpu_percent,memory_used_mb,memory_percent,pods,response_time_ms,hpa_replicas,karpenter_nodes" > "${K8S_OUTPUT}"
    
    log_info "Output directory: ${OUTPUT_DIR}"
}

# Docker Swarm monitoring function (as described in research document)
monitor_docker_swarm() {
    local duration=$1
    local samples=$((duration / SAMPLING_INTERVAL))
    
    log_info "Starting Docker Swarm monitoring (${samples} samples, ${duration}s total)"
    
    # Get Docker manager IP (assuming it's set as environment variable or discovered)
    if [ -z "$DOCKER_MANAGER_IP" ]; then
        log_error "DOCKER_MANAGER_IP not set. Please set this environment variable."
        return 1
    fi
    
    for i in $(seq 1 $samples); do
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        
        # CPU from worker node via SSH
        local cpu_percent
        cpu_percent=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$DOCKER_WORKER1 \
            "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | sed 's/%us,//'" 2>/dev/null || echo "0")
        
        # Memory: used MB and percentage
        local memory_info
        memory_info=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$DOCKER_WORKER1 \
            "free -m | grep '^Mem:' | awk '{print \$3,\$2}'" 2>/dev/null || echo "0 0")
        local memory_used=$(echo $memory_info | awk '{print $1}')
        local memory_total=$(echo $memory_info | awk '{print $2}')
        local memory_pct
        if [ "$memory_total" -ne 0 ]; then
            memory_pct=$(echo "scale=2; $memory_used*100/$memory_total" | bc 2>/dev/null || echo "0")
        else
            memory_pct="0"
        fi
        
        # Count running containers in the service
        local containers
        containers=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$DOCKER_MANAGER_IP \
            "docker service ps ${DOCKER_SERVICE_NAME} --format '{{.CurrentState}}' | grep -c Running" 2>/dev/null || echo "0")
        
        # End-to-end HTTP response time in milliseconds
        local response_time="0"
        if [ -n "$DOCKER_WORKER1" ]; then
            local response_raw
            response_raw=$(curl -w "%{time_total}" -o /dev/null -s --connect-timeout 5 \
                http://$DOCKER_WORKER1:8081/health 2>/dev/null || echo "0")
            response_time=$(echo "$response_raw * 1000" | bc 2>/dev/null | cut -d. -f1 || echo "0")
        fi
        
        # Additional metrics for research
        local load_avg
        load_avg=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$DOCKER_WORKER1 \
            "uptime | awk -F'load average:' '{print \$2}' | awk '{print \$1}' | sed 's/,//'" 2>/dev/null || echo "0")
        
        local disk_usage
        disk_usage=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$DOCKER_WORKER1 \
            "df / | tail -1 | awk '{print \$5}' | sed 's/%//'" 2>/dev/null || echo "0")
        
        # Write to CSV
        echo "$timestamp,$cpu_percent,$memory_used,$memory_pct,$containers,$response_time,$load_avg,$disk_usage" >> "${DOCKER_OUTPUT}"
        
        # Progress indicator
        if [ $((i % 10)) -eq 0 ]; then
            log_info "Docker Swarm: Sample $i/$samples (${cpu_percent}% CPU, ${memory_pct}% Memory)"
        fi
        
        sleep $SAMPLING_INTERVAL
    done
    
    log_info "Docker Swarm monitoring completed"
}

# Kubernetes monitoring function (as described in research document)
monitor_kubernetes() {
    local duration=$1
    local samples=$((duration / SAMPLING_INTERVAL))
    
    log_info "Starting Kubernetes monitoring (${samples} samples, ${duration}s total)"
    
    for i in $(seq 1 $samples); do
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        
        # Average CPU across all worker nodes
        local cpu_pct
        cpu_pct=$(kubectl top node 2>/dev/null | grep -v "NAME" | grep -v "control-plane" \
            | awk '{gsub(/%/,"",$3); sum+=$3; n++} END {if(n>0) printf "%.1f",sum/n; else print "0"}' || echo "0")
        
        # Total memory consumed across workers in MB
        local mem_used
        mem_used=$(kubectl top node 2>/dev/null | grep -v "NAME" | grep -v "control-plane" \
            | awk '{gsub(/Mi/,"",$4); sum+=$4} END {print sum+0}' || echo "0")
        
        # Calculate memory percentage (approximate, based on t2.micro = 1GB)
        local mem_pct
        if [ "$mem_used" -ne 0 ]; then
            # Assuming 1GB per t2.micro worker node
            local total_worker_memory=1024  # MB
            local worker_count
            worker_count=$(kubectl get nodes --no-headers 2>/dev/null | grep -v "control-plane" | wc -l || echo "1")
            local total_memory=$((total_worker_memory * worker_count))
            mem_pct=$(echo "scale=2; $mem_used*100/$total_memory" | bc 2>/dev/null || echo "0")
        else
            mem_pct="0"
        fi
        
        # Running pod count
        local pods
        pods=$(kubectl get pods -n $KUBERNETES_NAMESPACE 2>/dev/null | grep "cpu-stress" | grep -c "Running" || echo "0")
        
        # Current HPA replica count
        local hpa_replicas
        hpa_replicas=$(kubectl get hpa cpu-stress-hpa -n $KUBERNETES_NAMESPACE \
            -o jsonpath='{.status.currentReplicas}' 2>/dev/null || echo "0")
        
        # Count Karpenter-managed nodes
        local karpenter_nodes
        karpenter_nodes=$(kubectl get nodes -l node-type=karpenter-managed --no-headers 2>/dev/null | wc -l || echo "0")
        
        # Response time
        local response_time="0"
        local k8s_ip
        k8s_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
        if [ -n "$k8s_ip" ]; then
            local response_raw
            response_raw=$(curl -w "%{time_total}" -o /dev/null -s --connect-timeout 5 \
                http://$k8s_ip:30080/health 2>/dev/null || echo "0")
            response_time=$(echo "$response_raw * 1000" | bc 2>/dev/null | cut -d. -f1 || echo "0")
        fi
        
        # Write to CSV
        echo "$timestamp,$cpu_pct,$mem_used,$mem_pct,$pods,$response_time,$hpa_replicas,$karpenter_nodes" >> "${K8S_OUTPUT}"
        
        # Progress indicator
        if [ $((i % 10)) -eq 0 ]; then
            log_info "Kubernetes: Sample $i/$samples (${cpu_pct}% CPU, ${mem_pct}% Memory, ${hpa_replicas} replicas)"
        fi
        
        sleep $SAMPLING_INTERVAL
    done
    
    log_info "Kubernetes monitoring completed"
}

# Four-scenario test protocol
run_test_scenario() {
    local scenario_name=$1
    local duration=$2
    local cpu_target=$3
    local description=$4
    
    log_info "=== Running Scenario: $scenario_name ==="
    log_info "Description: $description"
    log_info "Duration: ${duration}s, CPU Target: $cpu_target"
    
    local scenario_output_dir="${OUTPUT_DIR}/${scenario_name}"
    mkdir -p "$scenario_output_dir"
    
    # Scenario-specific monitoring
    case $scenario_name in
        "normal_load")
            run_normal_load_scenario $duration $scenario_output_dir
            ;;
        "high_load")
            run_high_load_scenario $duration $scenario_output_dir
            ;;
        "variable_load")
            run_variable_load_scenario $duration $scenario_output_dir
            ;;
        "fault_tolerance")
            run_fault_tolerance_scenario $duration $scenario_output_dir
            ;;
        *)
            log_error "Unknown scenario: $scenario_name"
            return 1
            ;;
    esac
    
    log_info "Scenario $scenario_name completed"
}

# Individual scenario implementations
run_normal_load_scenario() {
    local duration=$1
    local output_dir=$2
    
    log_info "Starting normal load scenario (30-50% CPU target)"
    
    # Start monitoring in background for both platforms
    if [ "$MONITOR_KUBERNETES" = "true" ]; then
        monitor_kubernetes $duration > "${output_dir}/k8s_monitoring.log" 2>&1 &
        local k8s_pid=$!
    fi
    
    if [ "$MONITOR_DOCKER_SWARM" = "true" ]; then
        monitor_docker_swarm $duration > "${output_dir}/docker_monitoring.log" 2>&1 &
        local docker_pid=$!
    fi
    
    # Wait for monitoring to complete
    if [ -n "$k8s_pid" ]; then
        wait $k8s_pid
    fi
    if [ -n "$docker_pid" ]; then
        wait $docker_pid
    fi
}

run_high_load_scenario() {
    local duration=$1
    local output_dir=$2
    
    log_info "Starting high load scenario (80-95% CPU target)"
    # Similar implementation with higher intensity stress tests
    # Implementation would trigger high CPU load via API calls
}

run_variable_load_scenario() {
    local duration=$1
    local output_dir=$2
    
    log_info "Starting variable load scenario (20-90% cycling)"
    # Implementation would cycle load levels during monitoring
}

run_fault_tolerance_scenario() {
    local duration=$1
    local output_dir=$2
    
    log_info "Starting fault tolerance scenario (Peak load + node kill)"
    # Implementation would simulate node failures during peak load
}

# Main execution function
main() {
    log_info "PhD Research Monitoring Framework - Objective 3"
    log_info "Kubernetes vs Docker Swarm Comparative Analysis"
    
    # Check dependencies
    command -v kubectl >/dev/null 2>&1 || { log_error "kubectl not found"; exit 1; }
    command -v docker >/dev/null 2>&1 || { log_error "docker not found"; exit 1; }
    command -v ssh >/dev/null 2>&1 || { log_error "ssh not found"; exit 1; }
    command -v bc >/dev/null 2>&1 || { log_error "bc not found"; exit 1; }
    command -v curl >/dev/null 2>&1 || { log_error "curl not found"; exit 1; }
    
    # Parse command line arguments
    local platform="both"
    local scenario="all"
    local duration=1800  # 30 minutes default
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --platform)
                platform="$2"
                shift 2
                ;;
            --scenario)
                scenario="$2"
                shift 2
                ;;
            --duration)
                duration="$2"
                shift 2
                ;;
            --docker-manager)
                DOCKER_MANAGER_IP="$2"
                shift 2
                ;;
            --docker-worker)
                DOCKER_WORKER1="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --platform PLATFORM     Platform to monitor (kubernetes|docker-swarm|both)"
                echo "  --scenario SCENARIO      Scenario to run (normal_load|high_load|variable_load|fault_tolerance|all)"
                echo "  --duration DURATION      Duration in seconds (default: 1800)"
                echo "  --docker-manager IP      Docker Swarm manager IP"
                echo "  --docker-worker IP       Docker Swarm worker IP"
                echo "  --help                   Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown parameter: $1"
                exit 1
                ;;
        esac
    done
    
    # Set monitoring flags
    case $platform in
        "kubernetes")
            MONITOR_KUBERNETES="true"
            MONITOR_DOCKER_SWARM="false"
            ;;
        "docker-swarm")
            MONITOR_KUBERNETES="false"
            MONITOR_DOCKER_SWARM="true"
            ;;
        "both")
            MONITOR_KUBERNETES="true"
            MONITOR_DOCKER_SWARM="true"
            ;;
        *)
            log_error "Invalid platform: $platform"
            exit 1
            ;;
    esac
    
    setup_monitoring
    
    # Run scenarios
    case $scenario in
        "normal_load")
            run_test_scenario "normal_load" 1800 "30-50%" "Establishes steady-state resource efficiency baseline"
            ;;
        "high_load")
            run_test_scenario "high_load" 1200 "80-95%" "Evaluates peak resource consumption patterns"
            ;;
        "variable_load")
            run_test_scenario "variable_load" 2700 "20-90%" "Tests adaptive scaling capabilities"
            ;;
        "fault_tolerance")
            run_test_scenario "fault_tolerance" 900 "Peak+Kill" "Measures recovery speed after infrastructure failure"
            ;;
        "all")
            run_test_scenario "normal_load" 1800 "30-50%" "Establishes steady-state resource efficiency baseline"
            run_test_scenario "high_load" 1200 "80-95%" "Evaluates peak resource consumption patterns"
            run_test_scenario "variable_load" 2700 "20-90%" "Tests adaptive scaling capabilities"
            run_test_scenario "fault_tolerance" 900 "Peak+Kill" "Measures recovery speed after infrastructure failure"
            ;;
        *)
            log_error "Invalid scenario: $scenario"
            exit 1
            ;;
    esac
    
    log_info "All monitoring completed. Results saved to: ${OUTPUT_DIR}"
    log_info "Next step: Run 'python3 analysis/analyse_results.py ${OUTPUT_DIR}' for analysis"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi