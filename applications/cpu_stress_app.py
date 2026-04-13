#!/usr/bin/env python3
"""
Enhanced CPU Stress Application for PhD Research
Objectives 2 & 3: Kubernetes vs Docker Swarm Comparative Study

This application provides both CPU and memory stress testing capabilities
with detailed metrics collection for research analysis.
"""

import os
import time
import threading
import multiprocessing
import psutil
import json
import logging
from datetime import datetime
from flask import Flask, jsonify, request

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Global variables for stress control
cpu_stress_active = False
memory_stress_active = False
stress_threads = []
metrics_history = []

class StressTestManager:
    """Manages CPU and Memory stress testing with detailed metrics"""
    
    def __init__(self):
        self.start_time = time.time()
        self.cpu_stress_start = None
        self.memory_stress_start = None
        
    def cpu_stress_worker(self, duration=300, intensity=1.0):
        """
        CPU stress worker function
        
        Args:
            duration: How long to run stress test (seconds)
            intensity: CPU intensity (0.0 to 1.0)
        """
        global cpu_stress_active
        end_time = time.time() + duration
        self.cpu_stress_start = time.time()
        
        logger.info(f"Starting CPU stress: duration={duration}s, intensity={intensity}")
        
        while time.time() < end_time and cpu_stress_active:
            # Variable intensity busy loop
            work_cycles = int(1000000 * intensity)
            rest_cycles = int(1000000 * (1.0 - intensity))
            
            # Work phase
            for _ in range(work_cycles):
                pass
            
            # Optional rest phase for partial CPU usage
            if rest_cycles > 0:
                time.sleep(0.001)
    
    def memory_stress_worker(self, size_mb=100, duration=300, pattern='sequential'):
        """
        Memory stress worker function
        
        Args:
            size_mb: Amount of memory to allocate (MB)
            duration: How long to hold memory (seconds)
            pattern: Memory access pattern ('sequential', 'random', 'constant')
        """
        global memory_stress_active
        memory_blocks = []
        end_time = time.time() + duration
        self.memory_stress_start = time.time()
        
        logger.info(f"Starting memory stress: size={size_mb}MB, duration={duration}s, pattern={pattern}")
        
        try:
            # Allocation phase
            for i in range(size_mb):
                if not memory_stress_active or time.time() > end_time:
                    break
                    
                # Allocate 1MB block
                block = bytearray(1024 * 1024)
                
                # Initialize with pattern
                if pattern == 'sequential':
                    for j in range(0, len(block), 1024):
                        block[j:j+4] = i.to_bytes(4, 'little')
                elif pattern == 'random':
                    import random
                    for j in range(0, len(block), 1024):
                        block[j:j+4] = random.randint(0, 255).to_bytes(4, 'little')
                else:  # constant
                    block[:] = [i % 256] * len(block)
                
                memory_blocks.append(block)
                
                if i % 10 == 0:  # Progress logging
                    logger.info(f"Allocated {i+1}MB / {size_mb}MB")
                
                time.sleep(0.01)  # Small delay to prevent overwhelming system
            
            # Hold phase - keep accessing memory to prevent swapping
            logger.info(f"Memory allocated. Holding for {duration}s...")
            while time.time() < end_time and memory_stress_active:
                # Periodic memory access to keep it active
                if memory_blocks:
                    block_idx = int(time.time()) % len(memory_blocks)
                    if block_idx < len(memory_blocks):
                        # Touch the memory block
                        memory_blocks[block_idx][0] = (memory_blocks[block_idx][0] + 1) % 256
                
                time.sleep(1)
                
        except MemoryError as e:
            logger.error(f"Memory allocation failed: {e}")
        except Exception as e:
            logger.error(f"Memory stress error: {e}")
        finally:
            logger.info("Cleaning up memory blocks...")
            del memory_blocks

stress_manager = StressTestManager()

@app.route('/health')
def health():
    """
    Health check endpoint with detailed system status
    Research-grade metrics collection
    """
    try:
        # CPU metrics
        cpu_percent = psutil.cpu_percent(interval=1)
        cpu_count = multiprocessing.cpu_count()
        load_avg = os.getloadavg() if hasattr(os, 'getloadavg') else [0, 0, 0]
        
        # Memory metrics  
        memory = psutil.virtual_memory()
        memory_percent = memory.percent
        memory_available_mb = memory.available / 1024 / 1024
        memory_total_mb = memory.total / 1024 / 1024
        memory_used_mb = (memory.total - memory.available) / 1024 / 1024
        
        # Disk I/O (can affect memory performance)
        disk_usage = psutil.disk_usage('/')
        
        # Network (for completeness)
        network_io = psutil.net_io_counters()
        
        # Application-specific metrics
        uptime = time.time() - stress_manager.start_time
        cpu_stress_duration = (time.time() - stress_manager.cpu_stress_start) if stress_manager.cpu_stress_start else 0
        memory_stress_duration = (time.time() - stress_manager.memory_stress_start) if stress_manager.memory_stress_start else 0
        
        health_data = {
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'uptime_seconds': round(uptime, 2),
            
            # Stress test status
            'stress_tests': {
                'cpu_active': cpu_stress_active,
                'memory_active': memory_stress_active,
                'cpu_duration': round(cpu_stress_duration, 2),
                'memory_duration': round(memory_stress_duration, 2),
                'active_threads': len([t for t in stress_threads if t.is_alive()])
            },
            
            # System metrics
            'system': {
                'cpu': {
                    'usage_percent': cpu_percent,
                    'core_count': cpu_count,
                    'load_average': {
                        '1min': load_avg[0],
                        '5min': load_avg[1],
                        '15min': load_avg[2]
                    }
                },
                'memory': {
                    'usage_percent': memory_percent,
                    'total_mb': round(memory_total_mb, 2),
                    'used_mb': round(memory_used_mb, 2),
                    'available_mb': round(memory_available_mb, 2),
                    'free_mb': round(memory.free / 1024 / 1024, 2)
                },
                'disk': {
                    'total_gb': round(disk_usage.total / 1024 / 1024 / 1024, 2),
                    'used_gb': round(disk_usage.used / 1024 / 1024 / 1024, 2),
                    'free_gb': round(disk_usage.free / 1024 / 1024 / 1024, 2),
                    'usage_percent': round((disk_usage.used / disk_usage.total) * 100, 2)
                },
                'network': {
                    'bytes_sent': network_io.bytes_sent,
                    'bytes_recv': network_io.bytes_recv,
                    'packets_sent': network_io.packets_sent,
                    'packets_recv': network_io.packets_recv
                }
            }
        }
        
        # Store in metrics history for research
        metrics_history.append(health_data)
        
        # Keep only last 100 entries to prevent memory bloat
        if len(metrics_history) > 100:
            metrics_history.pop(0)
        
        return jsonify(health_data)
        
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500

@app.route('/start_cpu_stress')
def start_cpu_stress():
    """
    Start CPU stress test with configurable parameters
    """
    global cpu_stress_active, stress_threads
    
    try:
        if cpu_stress_active:
            return jsonify({
                'status': 'CPU stress already active',
                'active_since': stress_manager.cpu_stress_start
            }), 400
        
        # Parse parameters
        duration = int(request.args.get('duration', 300))  # 5 minutes default
        intensity = float(request.args.get('intensity', 1.0))  # 100% default
        thread_count = int(request.args.get('threads', multiprocessing.cpu_count()))
        
        # Validate parameters
        if not (0.1 <= intensity <= 1.0):
            return jsonify({'error': 'Intensity must be between 0.1 and 1.0'}), 400
        if not (1 <= thread_count <= multiprocessing.cpu_count() * 2):
            return jsonify({'error': f'Thread count must be between 1 and {multiprocessing.cpu_count() * 2}'}), 400
        if not (10 <= duration <= 3600):  # 10 seconds to 1 hour
            return jsonify({'error': 'Duration must be between 10 and 3600 seconds'}), 400
        
        cpu_stress_active = True
        
        # Start CPU stress threads
        for i in range(thread_count):
            thread = threading.Thread(
                target=stress_manager.cpu_stress_worker, 
                args=(duration, intensity),
                name=f'cpu-stress-{i}'
            )
            thread.start()
            stress_threads.append(thread)
        
        logger.info(f"Started CPU stress: {thread_count} threads, {intensity*100}% intensity, {duration}s duration")
        
        return jsonify({
            'status': 'CPU stress started',
            'parameters': {
                'duration': duration,
                'intensity': intensity,
                'threads': thread_count,
                'cpu_cores': multiprocessing.cpu_count()
            },
            'start_time': datetime.now().isoformat()
        })
        
    except ValueError as e:
        return jsonify({'error': f'Invalid parameter: {e}'}), 400
    except Exception as e:
        logger.error(f"Failed to start CPU stress: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/start_memory_stress')
def start_memory_stress():
    """
    Start memory stress test with configurable parameters
    """
    global memory_stress_active, stress_threads
    
    try:
        if memory_stress_active:
            return jsonify({
                'status': 'Memory stress already active',
                'active_since': stress_manager.memory_stress_start
            }), 400
        
        # Parse parameters
        size_mb = int(request.args.get('size_mb', 100))  # 100MB default
        duration = int(request.args.get('duration', 300))  # 5 minutes default
        pattern = request.args.get('pattern', 'sequential')  # sequential, random, constant
        
        # Validate parameters
        available_mb = psutil.virtual_memory().available / 1024 / 1024
        if not (10 <= size_mb <= available_mb * 0.8):  # Don't use more than 80% of available memory
            return jsonify({'error': f'Size must be between 10MB and {int(available_mb * 0.8)}MB'}), 400
        if not (10 <= duration <= 3600):
            return jsonify({'error': 'Duration must be between 10 and 3600 seconds'}), 400
        if pattern not in ['sequential', 'random', 'constant']:
            return jsonify({'error': 'Pattern must be sequential, random, or constant'}), 400
        
        memory_stress_active = True
        
        # Start memory stress thread
        thread = threading.Thread(
            target=stress_manager.memory_stress_worker,
            args=(size_mb, duration, pattern),
            name='memory-stress'
        )
        thread.start()
        stress_threads.append(thread)
        
        logger.info(f"Started memory stress: {size_mb}MB, {pattern} pattern, {duration}s duration")
        
        return jsonify({
            'status': 'Memory stress started',
            'parameters': {
                'size_mb': size_mb,
                'duration': duration,
                'pattern': pattern,
                'available_mb': round(available_mb, 2)
            },
            'start_time': datetime.now().isoformat()
        })
        
    except ValueError as e:
        return jsonify({'error': f'Invalid parameter: {e}'}), 400
    except Exception as e:
        logger.error(f"Failed to start memory stress: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/stop_stress')
def stop_stress():
    """
    Stop all active stress tests
    """
    global cpu_stress_active, memory_stress_active, stress_threads
    
    try:
        cpu_was_active = cpu_stress_active
        memory_was_active = memory_stress_active
        
        cpu_stress_active = False
        memory_stress_active = False
        
        # Wait for threads to finish (with timeout)
        active_threads = len(stress_threads)
        for thread in stress_threads[:]:  # Copy list to avoid modification during iteration
            thread.join(timeout=2)
            if not thread.is_alive():
                stress_threads.remove(thread)
        
        remaining_threads = len(stress_threads)
        
        logger.info(f"Stopped stress tests. {active_threads - remaining_threads} threads stopped, {remaining_threads} still running")
        
        return jsonify({
            'status': 'Stress tests stopped',
            'stopped': {
                'cpu_stress': cpu_was_active,
                'memory_stress': memory_was_active
            },
            'threads': {
                'total': active_threads,
                'stopped': active_threads - remaining_threads,
                'remaining': remaining_threads
            },
            'stop_time': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Failed to stop stress tests: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/metrics')
def get_metrics():
    """
    Get detailed system metrics for research analysis
    """
    try:
        return health()  # Reuse health endpoint for detailed metrics
    except Exception as e:
        logger.error(f"Failed to get metrics: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/metrics/history')
def get_metrics_history():
    """
    Get historical metrics for trend analysis
    """
    try:
        return jsonify({
            'history': metrics_history,
            'count': len(metrics_history),
            'oldest': metrics_history[0]['timestamp'] if metrics_history else None,
            'newest': metrics_history[-1]['timestamp'] if metrics_history else None
        })
    except Exception as e:
        logger.error(f"Failed to get metrics history: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/research/info')
def research_info():
    """
    Get research-specific information about this application instance
    """
    return jsonify({
        'research': {
            'project': 'PhD Research: Kubernetes vs Docker Swarm',
            'objectives': ['Objective 2: KMAB Framework', 'Objective 3: Comparative Analysis'],
            'application': 'Enhanced CPU/Memory Stress Tester',
            'version': '1.0.0',
            'platform': os.environ.get('PLATFORM', 'unknown'),
            'research_mode': os.environ.get('RESEARCH_MODE', 'unknown')
        },
        'capabilities': [
            'CPU stress testing with configurable intensity',
            'Memory stress testing with access patterns',
            'Real-time system metrics collection',
            'Historical metrics storage',
            'Research-grade logging and monitoring'
        ],
        'endpoints': [
            'GET /health - System status and metrics',
            'GET /start_cpu_stress?duration=X&intensity=Y&threads=Z - Start CPU stress',
            'GET /start_memory_stress?size_mb=X&duration=Y&pattern=Z - Start memory stress',
            'GET /stop_stress - Stop all stress tests',
            'GET /metrics - Current system metrics',
            'GET /metrics/history - Historical metrics',
            'GET /research/info - This information'
        ]
    })

if __name__ == '__main__':
    # Configuration
    host = os.environ.get('FLASK_HOST', '0.0.0.0')
    port = int(os.environ.get('FLASK_PORT', 8081))
    debug = os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'
    
    # Research environment identification
    platform = os.environ.get('PLATFORM', 'unknown')
    research_mode = os.environ.get('RESEARCH_MODE', 'unknown')
    
    logger.info(f"Starting PhD Research CPU Stress Application")
    logger.info(f"Platform: {platform}, Research Mode: {research_mode}")
    logger.info(f"Host: {host}, Port: {port}, Debug: {debug}")
    logger.info(f"CPU cores available: {multiprocessing.cpu_count()}")
    logger.info(f"Memory available: {psutil.virtual_memory().total / 1024 / 1024 / 1024:.2f} GB")
    
    # Start Flask application
    app.run(host=host, port=port, debug=debug, threaded=True)