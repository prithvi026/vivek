#!/bin/bash
"""
Fault Tolerance Test Script for PhD Research
Objective 3: Comparative Analysis - Fault Recovery Scenarios

This script implements the fault tolerance testing procedure described
in the research document, measuring detection latency and recovery speed.
"""

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_ROOT/results/fault_tolerance_$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Test configuration
setup_test_environment() {
    log_info "Setting up fault tolerance test environment"
    
    mkdir -p "$RESULTS_DIR"
    
    # Create test results file
    echo "timestamp,event_type,platform,detection_time_sec,recovery_time_sec,service_availability,notes" > "$RESULTS_DIR/fault_tolerance_results.csv"
    
    log_info "Results will be saved to: $RESULTS_DIR"
}

# Kubernetes fault tolerance test
test_kubernetes_fault_tolerance() {
    log_info "=== KUBERNETES FAULT TOLERANCE TEST ==="
    
    local test_start_time=$(date +%s)
    local platform="kubernetes"
    
    # Step 1: Verify initial state
    log_info "Step 1: Verifying initial Kubernetes state"
    local initial_pods=$(kubectl get pods --no-headers | grep cpu-stress | grep Running | wc -l)
    local initial_nodes=$(kubectl get nodes --no-headers | grep -v control-plane | wc -l)
    
    log_info "Initial state: $initial_pods running pods, $initial_nodes worker nodes"
    
    # Step 2: Start peak load
    log_info "Step 2: Starting peak load on Kubernetes"
    local k8s_service_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
    
    if [ -n "$k8s_service_ip" ]; then
        # Start CPU stress to create peak load
        curl -s "http://$k8s_service_ip:30080/start_cpu_stress?duration=600&intensity=0.9" > /dev/null || log_warn "Failed to start CPU stress"
        curl -s "http://$k8s_service_ip:30080/start_memory_stress?size_mb=200&duration=600" > /dev/null || log_warn "Failed to start memory stress"
        sleep 30  # Let load stabilize
    else
        log_error "Could not determine Kubernetes service IP"
        return 1
    fi
    
    # Step 3: Identify target worker node
    local target_node=$(kubectl get nodes --no-headers | grep -v control-plane | head -n1 | awk '{print $1}')
    if [ -z "$target_node" ]; then
        log_error "No worker nodes found"
        return 1
    fi
    
    log_info "Step 3: Target node for fault injection: $target_node"
    
    # Step 4: Record baseline metrics
    log_info "Step 4: Recording baseline metrics"
    local baseline_response_time
    if [ -n "$k8s_service_ip" ]; then
        baseline_response_time=$(curl -w "%{time_total}" -o /dev/null -s --connect-timeout 5 \
            "http://$k8s_service_ip:30080/health" 2>/dev/null || echo "0")
    else
        baseline_response_time="0"
    fi
    
    log_info "Baseline response time: ${baseline_response_time}s"
    
    # Step 5: Inject fault - Cordon and drain node
    log_info "Step 5: FAULT INJECTION - Cordoning and draining node $target_node"
    local fault_injection_time=$(date +%s)
    
    # Cordon the node (prevents new pods)
    kubectl cordon "$target_node" > /dev/null 2>&1
    
    # Drain the node (evicts existing pods)
    kubectl drain "$target_node" --ignore-daemonsets --delete-emptydir-data --force --timeout=60s > /dev/null 2>&1 &
    local drain_pid=$!
    
    # Step 6: Monitor detection and recovery
    log_info "Step 6: Monitoring fault detection and recovery"
    
    local detection_time=0
    local recovery_time=0
    local service_restored=false
    local max_wait_time=300  # 5 minutes max
    local check_interval=5
    
    for ((i=0; i<max_wait_time; i+=check_interval)); do
        sleep $check_interval
        local current_time=$(date +%s)
        
        # Check if Kubernetes has detected the issue (pods rescheduling)
        if [ $detection_time -eq 0 ]; then
            local pending_pods=$(kubectl get pods --no-headers | grep cpu-stress | grep -c Pending || echo "0")
            if [ "$pending_pods" -gt 0 ]; then
                detection_time=$((current_time - fault_injection_time))
                log_info "DETECTION: Kubernetes detected fault in ${detection_time}s (pending pods: $pending_pods)"
            fi
        fi
        
        # Check if service is restored (all pods running again)
        if [ $recovery_time -eq 0 ]; then
            local running_pods=$(kubectl get pods --no-headers | grep cpu-stress | grep -c Running || echo "0")
            if [ "$running_pods" -ge "$initial_pods" ]; then
                recovery_time=$((current_time - fault_injection_time))
                log_info "RECOVERY: Service restored in ${recovery_time}s (running pods: $running_pods)"
                service_restored=true
                break
            fi
        fi
        
        # Log progress
        if [ $((i % 30)) -eq 0 ]; then
            local current_running=$(kubectl get pods --no-headers | grep cpu-stress | grep -c Running || echo "0")
            local current_pending=$(kubectl get pods --no-headers | grep cpu-stress | grep -c Pending || echo "0")
            log_info "Progress: ${i}s elapsed, Running: $current_running, Pending: $current_pending"
        fi
    done
    
    # Wait for drain to complete
    wait $drain_pid 2>/dev/null || true
    
    # Step 7: Record results
    local test_end_time=$(date +%s)
    local total_test_time=$((test_end_time - test_start_time))
    
    if [ $service_restored = true ]; then
        log_info "✅ KUBERNETES FAULT TOLERANCE TEST PASSED"
        log_info "Detection Time: ${detection_time}s"
        log_info "Recovery Time: ${recovery_time}s" 
        log_info "Total Test Duration: ${total_test_time}s"
    else
        log_warn "⚠️ KUBERNETES FAULT TOLERANCE TEST INCOMPLETE"
        log_warn "Service may not have fully recovered within timeout"
        recovery_time=$max_wait_time
    fi
    
    # Save results
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp,fault_injection,$platform,$detection_time,$recovery_time,$service_restored,Node: $target_node cordoned and drained" >> "$RESULTS_DIR/fault_tolerance_results.csv"
    
    # Step 8: Cleanup - uncordon the node
    log_info "Step 8: Cleanup - uncordoning node $target_node"
    kubectl uncordon "$target_node" > /dev/null 2>&1 || log_warn "Failed to uncordon node"
    
    # Stop stress tests
    if [ -n "$k8s_service_ip" ]; then
        curl -s "http://$k8s_service_ip:30080/stop_stress" > /dev/null || log_warn "Failed to stop stress tests"
    fi
    
    return 0
}

# Docker Swarm fault tolerance test  
test_docker_swarm_fault_tolerance() {
    log_info "=== DOCKER SWARM FAULT TOLERANCE TEST ==="
    
    local test_start_time=$(date +%s)
    local platform="docker_swarm"
    
    # Check if Docker Swarm environment variables are set
    if [ -z "$DOCKER_MANAGER_IP" ] || [ -z "$DOCKER_WORKER1" ] || [ -z "$DOCKER_WORKER2" ]; then
        log_error "Docker Swarm environment variables not set"
        log_error "Please set: DOCKER_MANAGER_IP, DOCKER_WORKER1, DOCKER_WORKER2"
        return 1
    fi
    
    # Step 1: Verify initial state
    log_info "Step 1: Verifying initial Docker Swarm state"
    local initial_containers
    initial_containers=$(ssh -o ConnectTimeout=5 ubuntu@$DOCKER_MANAGER_IP \
        "docker service ps phd-research_cpu-stress-app --format '{{.CurrentState}}' | grep -c Running" 2>/dev/null || echo "0")
    
    log_info "Initial state: $initial_containers running containers"
    
    # Step 2: Start peak load
    log_info "Step 2: Starting peak load on Docker Swarm"
    
    # Start stress on both workers
    curl -s "http://$DOCKER_WORKER1:8081/start_cpu_stress?duration=600&intensity=0.9" > /dev/null || log_warn "Failed to start CPU stress on worker 1"
    curl -s "http://$DOCKER_WORKER2:8081/start_cpu_stress?duration=600&intensity=0.9" > /dev/null || log_warn "Failed to start CPU stress on worker 2"
    curl -s "http://$DOCKER_WORKER1:8081/start_memory_stress?size_mb=200&duration=600" > /dev/null || log_warn "Failed to start memory stress on worker 1"
    curl -s "http://$DOCKER_WORKER2:8081/start_memory_stress?size_mb=200&duration=600" > /dev/null || log_warn "Failed to start memory stress on worker 2"
    
    sleep 30  # Let load stabilize
    
    # Step 3: Record baseline metrics
    log_info "Step 3: Recording baseline metrics"
    local baseline_response_time
    baseline_response_time=$(curl -w "%{time_total}" -o /dev/null -s --connect-timeout 5 \
        "http://$DOCKER_WORKER1:8081/health" 2>/dev/null || echo "0")
    
    log_info "Baseline response time: ${baseline_response_time}s"
    
    # Step 4: Inject fault - Stop Docker daemon on worker 2
    log_info "Step 4: FAULT INJECTION - Stopping Docker daemon on worker 2"
    local fault_injection_time=$(date +%s)
    
    ssh -o ConnectTimeout=5 ubuntu@$DOCKER_WORKER2 "sudo systemctl stop docker" > /dev/null 2>&1 || log_warn "Failed to stop Docker on worker 2"
    
    # Step 5: Monitor detection and recovery
    log_info "Step 5: Monitoring fault detection and recovery"
    
    local detection_time=0
    local recovery_time=0
    local service_restored=false
    local max_wait_time=300  # 5 minutes max
    local check_interval=10
    
    for ((i=0; i<max_wait_time; i+=check_interval)); do
        sleep $check_interval
        local current_time=$(date +%s)
        
        # Check current container count
        local current_containers
        current_containers=$(ssh -o ConnectTimeout=5 ubuntu@$DOCKER_MANAGER_IP \
            "docker service ps phd-research_cpu-stress-app --format '{{.CurrentState}}' | grep -c Running" 2>/dev/null || echo "0")
        
        # Check if Docker Swarm has detected the issue
        if [ $detection_time -eq 0 ]; then
            if [ "$current_containers" -lt "$initial_containers" ]; then
                detection_time=$((current_time - fault_injection_time))
                log_info "DETECTION: Docker Swarm detected fault in ${detection_time}s (containers: $current_containers)"
            fi
        fi
        
        # Check if service is restored
        if [ $recovery_time -eq 0 ] && [ "$current_containers" -ge "$initial_containers" ]; then
            recovery_time=$((current_time - fault_injection_time))
            log_info "RECOVERY: Service restored in ${recovery_time}s (containers: $current_containers)"
            service_restored=true
            break
        fi
        
        # Log progress
        log_info "Progress: ${i}s elapsed, Running containers: $current_containers"
    done
    
    # Step 6: Record results
    local test_end_time=$(date +%s)
    local total_test_time=$((test_end_time - test_start_time))
    
    if [ $service_restored = true ]; then
        log_info "✅ DOCKER SWARM FAULT TOLERANCE TEST PASSED"
        log_info "Detection Time: ${detection_time}s"
        log_info "Recovery Time: ${recovery_time}s"
        log_info "Total Test Duration: ${total_test_time}s"
    else
        log_warn "⚠️ DOCKER SWARM FAULT TOLERANCE TEST INCOMPLETE"
        log_warn "Service may not have fully recovered within timeout"
        if [ $detection_time -eq 0 ]; then
            detection_time=$max_wait_time
        fi
        recovery_time=$max_wait_time
    fi
    
    # Save results
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp,fault_injection,$platform,$detection_time,$recovery_time,$service_restored,Docker daemon stopped on worker 2" >> "$RESULTS_DIR/fault_tolerance_results.csv"
    
    # Step 7: Cleanup - restart Docker daemon
    log_info "Step 7: Cleanup - restarting Docker daemon on worker 2"
    ssh -o ConnectTimeout=5 ubuntu@$DOCKER_WORKER2 "sudo systemctl start docker" > /dev/null 2>&1 || log_warn "Failed to start Docker on worker 2"
    
    # Give Docker time to rejoin swarm
    sleep 30
    
    # Stop stress tests
    curl -s "http://$DOCKER_WORKER1:8081/stop_stress" > /dev/null || log_warn "Failed to stop stress on worker 1"
    curl -s "http://$DOCKER_WORKER2:8081/stop_stress" > /dev/null || log_warn "Failed to stop stress on worker 2"
    
    return 0
}

# Generate fault tolerance report
generate_fault_tolerance_report() {
    log_info "Generating fault tolerance comparison report"
    
    if [ ! -f "$RESULTS_DIR/fault_tolerance_results.csv" ]; then
        log_error "No fault tolerance results found"
        return 1
    fi
    
    # Create summary report
    cat > "$RESULTS_DIR/fault_tolerance_summary.md" << EOF
# Fault Tolerance Test Results
## PhD Research: Kubernetes vs Docker Swarm

**Test Date:** $(date '+%Y-%m-%d %H:%M:%S')

## Test Scenarios

### Test Procedure
1. **Peak Load Generation**: Both platforms loaded to 90% CPU + 200MB memory stress
2. **Fault Injection**: 
   - Kubernetes: Worker node cordoned and drained
   - Docker Swarm: Docker daemon stopped on worker node
3. **Recovery Monitoring**: Detection and recovery times measured
4. **Service Restoration**: Verified full service availability

## Results Summary

EOF
    
    # Parse CSV results
    if command -v python3 >/dev/null 2>&1; then
        python3 << EOF >> "$RESULTS_DIR/fault_tolerance_summary.md"
import csv
import sys

try:
    with open('$RESULTS_DIR/fault_tolerance_results.csv', 'r') as f:
        reader = csv.DictReader(f)
        results = list(reader)
    
    for result in results:
        platform = result['platform'].replace('_', ' ').title()
        detection = result['detection_time_sec']
        recovery = result['recovery_time_sec']
        availability = result['service_availability']
        notes = result['notes']
        
        print(f"### {platform}")
        print(f"- **Detection Time**: {detection}s")
        print(f"- **Recovery Time**: {recovery}s")
        print(f"- **Service Restored**: {availability}")
        print(f"- **Method**: {notes}")
        print("")
        
except Exception as e:
    print(f"Error processing results: {e}")
EOF
    else
        echo "Python3 not available for detailed report generation" >> "$RESULTS_DIR/fault_tolerance_summary.md"
    fi
    
    # Add research findings
    cat >> "$RESULTS_DIR/fault_tolerance_summary.md" << EOF

## Research Findings

### Expected Results (from Research Document)
- **Kubernetes**: 30-60 seconds recovery time
- **Docker Swarm**: 2-3 minutes recovery time

### Key Observations
1. **Detection Speed**: How quickly each platform identified the fault
2. **Recovery Automation**: Level of manual intervention required
3. **Service Continuity**: Availability during recovery process

### Next Steps
1. Review detailed timing data
2. Compare with research hypothesis
3. Document findings for thesis Chapter 4.3

## Files Generated
- \`fault_tolerance_results.csv\` - Raw timing data
- \`fault_tolerance_summary.md\` - This summary report

EOF
    
    log_info "Fault tolerance report generated: $RESULTS_DIR/fault_tolerance_summary.md"
}

# Main execution function
main() {
    log_info "PhD Research Fault Tolerance Testing Framework"
    log_info "Objective 3: Kubernetes vs Docker Swarm Recovery Analysis"
    
    # Parse command line arguments
    local test_platform="both"
    local skip_cleanup=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --platform)
                test_platform="$2"
                shift 2
                ;;
            --skip-cleanup)
                skip_cleanup=true
                shift
                ;;
            --docker-manager)
                DOCKER_MANAGER_IP="$2"
                shift 2
                ;;
            --docker-worker1)
                DOCKER_WORKER1="$2"
                shift 2
                ;;
            --docker-worker2)
                DOCKER_WORKER2="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --platform PLATFORM     Platform to test (kubernetes|docker-swarm|both)"
                echo "  --skip-cleanup           Don't cleanup after tests"
                echo "  --docker-manager IP      Docker Swarm manager IP"
                echo "  --docker-worker1 IP      Docker Swarm worker 1 IP"
                echo "  --docker-worker2 IP      Docker Swarm worker 2 IP"
                echo "  --help                   Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown parameter: $1"
                exit 1
                ;;
        esac
    done
    
    # Setup test environment
    setup_test_environment
    
    # Run tests
    case $test_platform in
        "kubernetes")
            test_kubernetes_fault_tolerance
            ;;
        "docker-swarm")
            test_docker_swarm_fault_tolerance
            ;;
        "both")
            test_kubernetes_fault_tolerance
            echo ""
            test_docker_swarm_fault_tolerance
            ;;
        *)
            log_error "Invalid platform: $test_platform"
            exit 1
            ;;
    esac
    
    # Generate report
    generate_fault_tolerance_report
    
    log_info "Fault tolerance testing completed"
    log_info "Results saved to: $RESULTS_DIR"
}

# Export functions for external use
export -f log_info log_warn log_error
export -f test_kubernetes_fault_tolerance test_docker_swarm_fault_tolerance

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi