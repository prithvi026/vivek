# KMAB Algorithm Flow Diagram
## Visual Representation for Thesis/Presentations

---

## DIAGRAM 1: Complete KMAB Algorithm Flow

```
╔═══════════════════════════════════════════════════════════════════════╗
║                        KMAB ALGORITHM FLOW                            ║
║           (Karpenter Memory-Aware Bin-packing Framework)              ║
╚═══════════════════════════════════════════════════════════════════════╝

                              START
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                     PHASE 1: OBSERVATION                              │
│                                                                       │
│  Monitor Kubernetes API for unschedulable pods                       │
│  ────────────────────────────────────────────                        │
│                                                                       │
│  📊 Input: Kubernetes Scheduler events                               │
│  🔍 Check: Any pods with status = "Unschedulable"?                   │
│                                                                       │
│      YES: Pods waiting for resources → Go to Phase 2                 │
│      NO:  All pods scheduled → Continue monitoring                   │
└───────────────────────────────────────────────────────────────────────┘
                                │
                                │ YES (Unschedulable pods detected)
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                  PHASE 2: BIN-PACK OPTIMIZATION                       │
│                 ✨ YOUR INNOVATION 1: Memory-Aware Scoring ✨         │
│                                                                       │
│  Calculate memory-aware score for each instance type:                │
│  ─────────────────────────────────────────────────────               │
│                                                                       │
│  For each instance type t ∈ {t2.micro, t3.micro, t3.small}:         │
│                                                                       │
│  Step 1: Calculate fit_count                                         │
│  ┌───────────────────────────────────────────────────┐               │
│  │ fit_count(t) = ⌊node_memory(t) / pod_request⌋    │               │
│  │                                                   │               │
│  │ Example: t2.micro (1024 MiB) / 128 MiB = 8 pods  │               │
│  └───────────────────────────────────────────────────┘               │
│                                                                       │
│  Step 2: Calculate waste_ratio                                       │
│  ┌───────────────────────────────────────────────────────────────┐   │
│  │ waste_ratio(t) = (node_memory - fit_count × request)         │   │
│  │                  ─────────────────────────────────           │   │
│  │                         node_memory                          │   │
│  │                                                              │   │
│  │ Example: (1024 - 8×128) / 1024 = 0 / 1024 = 0.0 (perfect!)  │   │
│  └───────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  Step 3: Calculate KMAB score                                        │
│  ┌─────────────────────────────────────────────────┐                 │
│  │ score(t) = fit_count(t)                         │                 │
│  │            ────────────────────                 │                 │
│  │            waste_ratio(t) + 0.001               │                 │
│  │                                                 │                 │
│  │ Example: 8 / (0.0 + 0.001) = 8000              │                 │
│  └─────────────────────────────────────────────────┘                 │
│                                                                       │
│  Step 4: Select best instance                                        │
│  ┌─────────────────────────────────────┐                             │
│  │ t_best = argmax(score)              │                             │
│  │                                     │                             │
│  │ Select instance with HIGHEST score  │                             │
│  └─────────────────────────────────────┘                             │
│                                                                       │
│  📊 Output: Optimal instance type (e.g., t3.small)                   │
└───────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                      PHASE 3: PROVISIONING                            │
│                                                                       │
│  Launch selected EC2 instance via AWS API                            │
│  ────────────────────────────────────────────                        │
│                                                                       │
│  Step 1: Call AWS EC2 API                                            │
│  ┌─────────────────────────────────────────────┐                     │
│  │ aws_ec2.run_instances(                      │                     │
│  │   InstanceType: t_best,  // from Phase 2    │                     │
│  │   ImageId: "ami-k8s-node",                  │                     │
│  │   Tags: ["karpenter.sh/nodepool=memory"]    │                     │
│  │ )                                           │                     │
│  └─────────────────────────────────────────────┘                     │
│                                                                       │
│  Step 2: Wait for instance to start (~30s)                           │
│  Step 3: Wait for kubelet to join cluster (~15s)                     │
│                                                                       │
│  📊 Output: New node added to cluster (Ready status)                 │
│                                                                       │
│  ⏱️  Total time: ~45-60 seconds                                       │
└───────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                  PHASE 4: HPA LOOP (Real-time Scaling)                │
│                 ✨ YOUR INNOVATION 3: Dual-Metric HPA ✨              │
│                                                                       │
│  Horizontal Pod Autoscaler scales replicas based on CPU + Memory     │
│  ────────────────────────────────────────────────────────────        │
│                                                                       │
│  Every 15 seconds:                                                   │
│                                                                       │
│  Step 1: Get metrics from Metrics Server                             │
│  ┌────────────────────────────────────────┐                          │
│  │ current_cpu_util = 85%                 │                          │
│  │ current_mem_util = 90%                 │                          │
│  └────────────────────────────────────────┘                          │
│                                                                       │
│  Step 2: Calculate desired replicas (CPU)                            │
│  ┌──────────────────────────────────────────────────┐                │
│  │ desired_cpu = ⌈current_replicas ×               │                │
│  │                (current_cpu / target_cpu)⌉       │                │
│  │                                                  │                │
│  │ Example: ⌈2 × (85% / 70%)⌉ = ⌈2.43⌉ = 3        │                │
│  └──────────────────────────────────────────────────┘                │
│                                                                       │
│  Step 3: Calculate desired replicas (Memory)                         │
│  ┌──────────────────────────────────────────────────┐                │
│  │ desired_mem = ⌈current_replicas ×               │                │
│  │                (current_mem / target_mem)⌉       │                │
│  │                                                  │                │
│  │ Example: ⌈2 × (90% / 80%)⌉ = ⌈2.25⌉ = 3        │                │
│  └──────────────────────────────────────────────────┘                │
│                                                                       │
│  Step 4: Select maximum (most conservative)                          │
│  ┌────────────────────────────────────────┐                          │
│  │ desired = max(desired_cpu, desired_mem)│                          │
│  │         = max(3, 3) = 3                │                          │
│  │                                        │                          │
│  │ Constrain: clamp(3, min=2, max=5) = 3 │                          │
│  └────────────────────────────────────────┘                          │
│                                                                       │
│  Step 5: Scale replicas                                              │
│  • If scaling UP: Wait 30s stabilization → Create pods               │
│  • If scaling DOWN: Wait 60s stabilization → Delete pods             │
│                                                                       │
│  📊 Output: Adjusted replica count (2 → 3)                           │
│                                                                       │
│  🔁 If new pods unschedulable → Trigger Phase 1 again                │
└───────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                     PHASE 5: CONSOLIDATION                            │
│            ✨ YOUR INNOVATION 2: Aggressive 30% Threshold ✨          │
│                                                                       │
│  Every 30 seconds, check each node for underutilization              │
│  ────────────────────────────────────────────────────────            │
│                                                                       │
│  For each active node:                                               │
│                                                                       │
│  Step 1: Calculate memory utilization                                │
│  ┌──────────────────────────────────────────────┐                    │
│  │ mem_util = used_memory / allocatable_memory  │                    │
│  │                                              │                    │
│  │ Example: 256 MiB / 950 MiB = 27%            │                    │
│  └──────────────────────────────────────────────┘                    │
│                                                                       │
│  Step 2: Check threshold                                             │
│  ┌──────────────────────────────┐                                    │
│  │ Is mem_util < 30%?           │                                    │
│  │   YES: Node is underutilized │                                    │
│  │   NO:  Node is busy          │                                    │
│  └──────────────────────────────┘                                    │
│      │                     │                                          │
│      │ YES (27% < 30%)     │ NO                                       │
│      ▼                     └──→ Skip this node                        │
│                                                                       │
│  Step 3: Check if pods can reschedule                                │
│  ┌───────────────────────────────────────────────┐                   │
│  │ For each pod on this node:                    │                   │
│  │   Can it fit on another node?                 │                   │
│  │     Check: other_node.free_memory ≥ pod.req   │                   │
│  │                                               │                   │
│  │ If ALL pods can reschedule: YES               │                   │
│  │ If ANY pod cannot reschedule: NO              │                   │
│  └───────────────────────────────────────────────┘                   │
│      │                     │                                          │
│      │ YES                 │ NO                                       │
│      ▼                     └──→ Cannot consolidate (keep node)        │
│                                                                       │
│  Step 4: Consolidate node                                            │
│  ┌────────────────────────────────────┐                              │
│  │ 1. Cordon (prevent new pods)       │                              │
│  │ 2. Drain (evict pods, 60s grace)   │                              │
│  │ 3. Terminate EC2 instance          │                              │
│  │ 4. Free memory returned to AWS     │                              │
│  └────────────────────────────────────┘                              │
│                                                                       │
│  📊 Output: Node terminated, cluster resources optimized             │
│                                                                       │
│  ⏱️  Total cleanup time: 30-60 seconds                                │
│     (vs 120-300s standard Karpenter)                                 │
└───────────────────────────────────────────────────────────────────────┘
                                │
                                │
                                ▼
                        ┌───────────────┐
                        │ CONTINUOUS    │
                        │ LOOP BACK TO  │
                        │ PHASE 1       │
                        └───────────────┘
                                │
                                └──────► Back to PHASE 1 (monitor)


╔═══════════════════════════════════════════════════════════════════════╗
║                           KEY METRICS                                 ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  • Phase 1 → Phase 3: ~60 seconds (pod creation to node ready)       ║
║  • Phase 4 evaluation: Every 15 seconds                              ║
║  • Phase 5 consolidation: Every 30 seconds                           ║
║  • Memory utilization: 85-90% (vs 60-70% Docker Swarm)               ║
║  • Memory waste reduction: 71% vs baseline                           ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
```

---

## DIAGRAM 2: Comparison - Standard Karpenter vs KMAB

```
╔═══════════════════════════════════════════════════════════════════════╗
║                    STANDARD KARPENTER                                 ║
╚═══════════════════════════════════════════════════════════════════════╝

Pod needs resources
        │
        ▼
┌──────────────────┐
│ Observe          │  Watches unschedulable pods
└──────────────────┘
        │
        ▼
┌──────────────────┐
│ Bin-pack         │  ❌ CPU-first strategy
│                  │  score = f(CPU, cost)
└──────────────────┘  Memory is secondary
        │
        ▼
┌──────────────────┐
│ Provision        │  Launch EC2 instance
└──────────────────┘
        │
        ▼
┌──────────────────┐
│ Consolidate      │  ❌ Slow (60-300 seconds)
│                  │  ❌ No explicit memory threshold
└──────────────────┘  ❌ Conservative cleanup

HPA runs independently (NO integration)

RESULT: 
• Memory utilization: 60-70%
• Memory waste: ~300 MiB
• Cleanup time: 120-300 seconds


╔═══════════════════════════════════════════════════════════════════════╗
║                           KMAB                                        ║
╚═══════════════════════════════════════════════════════════════════════╝

Pod needs resources
        │
        ▼
┌──────────────────┐
│ PHASE 1          │  Watches unschedulable pods
│ Observe          │
└──────────────────┘
        │
        ▼
┌──────────────────┐
│ PHASE 2          │  ✅ MEMORY-AWARE strategy
│ Bin-pack         │  score = fit_count / (waste_ratio + ε)
│ ✨ INNOVATION 1  │  Minimizes memory waste
└──────────────────┘
        │
        ▼
┌──────────────────┐
│ PHASE 3          │  Launch EC2 instance (optimal memory fit)
│ Provision        │
└──────────────────┘
        │
        ▼
┌──────────────────┐
│ PHASE 4          │  ✅ INTEGRATED with HPA
│ HPA Loop         │  Dual-metric: max(CPU, Memory)
│ ✨ INNOVATION 3  │  Coordinated scaling
└──────────────────┘
        │
        ▼
┌──────────────────┐
│ PHASE 5          │  ✅ AGGRESSIVE (30 seconds)
│ Consolidate      │  ✅ Explicit 30% memory threshold
│ ✨ INNOVATION 2  │  ✅ Fast cleanup
└──────────────────┘

Continuous feedback loop (all phases integrated)

RESULT:
• Memory utilization: 85-90%
• Memory waste: ~86 MiB
• Cleanup time: 30-60 seconds
• 71% waste reduction vs Docker Swarm
```

---

## DIAGRAM 3: Example Scenario Walkthrough

```
╔═══════════════════════════════════════════════════════════════════════╗
║              EXAMPLE: Load Spike and Cleanup Cycle                    ║
╚═══════════════════════════════════════════════════════════════════════╝

TIME: T=0 (Initial State)
━━━━━━━━━━━━━━━━━━━━━━
Cluster: 1 node (t2.micro, 1024 MiB)
Pods: 2 replicas (each 128 MiB request)
Memory utilization: 256/1024 = 25%

┌─────────────┐
│ Node 1      │
│ ┌─────┐     │  Pod 1: 128 MiB
│ │ P1  │     │
│ ├─────┤     │  Pod 2: 128 MiB
│ │ P2  │     │
│ ├─────┤     │
│ │     │     │  Free: 768 MiB
│ │FREE │     │
│ │     │     │
│ └─────┘     │
└─────────────┘


TIME: T+10s (Load Spike)
━━━━━━━━━━━━━━━━━━━━━━━━━━
Application receives traffic
Memory usage increases to 85%

[PHASE 4 - HPA detects]
desired_mem = ⌈2 × (85%/80%)⌉ = 3 replicas
HPA creates Pod 3


TIME: T+12s (Pod 3 Unschedulable)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Pod 3 cannot fit on Node 1 (only 150 MiB free)

┌─────────────┐      ┌─────────────┐
│ Node 1      │      │ Pod 3       │
│ ┌─────┐     │      │ [PENDING]   │
│ │ P1  │     │      │ 128 MiB     │
│ ├─────┤     │      │ requested   │
│ │ P2  │     │      └─────────────┘
│ ├─────┤     │             │
│ │FREE │     │             ▼
│ │150  │     │      Status: Unschedulable
│ └─────┘     │      (insufficient memory)
└─────────────┘

[PHASE 1 - Karpenter observes unschedulable pod]


TIME: T+15s (Bin-pack Calculation)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[PHASE 2 - Memory-aware scoring]

Pod request: 128 MiB
Candidate instances:

┌──────────────────────────────────────────────────┐
│ Instance  │ Memory │ fit_count │ waste │ score   │
├───────────┼────────┼───────────┼───────┼─────────┤
│ t2.micro  │ 1024   │ 8         │ 0.0   │ 8000    │
│ t3.small  │ 2048   │ 16        │ 0.0   │ 16000 ✓ │
│ t3.medium │ 4096   │ 32        │ 0.0   │ 32000   │
└──────────────────────────────────────────────────┘

KMAB selects: t3.small (best fit for current workload)
Standard Karpenter might select: t3.medium (more CPU)


TIME: T+60s (New Node Ready)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[PHASE 3 - EC2 instance provisioned]

┌─────────────┐      ┌─────────────┐
│ Node 1      │      │ Node 2      │
│ ┌─────┐     │      │ ┌─────┐     │
│ │ P1  │     │      │ │ P3  │     │  Pod 3 scheduled
│ ├─────┤     │      │ ├─────┤     │
│ │ P2  │     │      │ │     │     │
│ ├─────┤     │      │ │FREE │     │  Free: 1920 MiB
│ │FREE │     │      │ │1920 │     │
│ └─────┘     │      │ └─────┘     │
└─────────────┘      └─────────────┘
  t2.micro             t3.small (2048 MiB)

Total memory: 3072 MiB
Utilization: 384/3072 = 12.5%


TIME: T+5min (Load Drops)
━━━━━━━━━━━━━━━━━━━━━━━━━━
Traffic decreases
Memory usage drops to 50%

[PHASE 4 - HPA scales down]
desired_mem = ⌈3 × (50%/80%)⌉ = 2 replicas
HPA deletes Pod 3

┌─────────────┐      ┌─────────────┐
│ Node 1      │      │ Node 2      │
│ ┌─────┐     │      │ ┌─────┐     │
│ │ P1  │     │      │ │EMPTY│     │  No pods
│ ├─────┤     │      │ │     │     │
│ │ P2  │     │      │ │     │     │
│ ├─────┤     │      │ │     │     │
│ │FREE │     │      │ │     │     │
│ └─────┘     │      │ └─────┘     │
└─────────────┘      └─────────────┘
                     Memory util: 0%


TIME: T+5min+30s (Consolidation Triggered)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[PHASE 5 - 30-second check detects underutilization]

Node 2 memory utilization: 0% < 30% ✓
All pods can reschedule: YES ✓

ACTION: Terminate Node 2

┌─────────────┐      
│ Node 1      │      Node 2: TERMINATED ❌
│ ┌─────┐     │      
│ │ P1  │     │      Freed: 2048 MiB
│ ├─────┤     │      
│ │ P2  │     │      Time to cleanup: 45 seconds
│ ├─────┤     │      (vs 120-300s standard Karpenter)
│ │FREE │     │      
│ └─────┘     │      
└─────────────┘      

Total memory: 1024 MiB
Utilization: 256/1024 = 25%
Waste: 768 MiB (temporary, will scale if needed)


╔═══════════════════════════════════════════════════════════════════════╗
║                         CYCLE SUMMARY                                 ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  • T=0 to T+60s: Scale-up (2 pods → 3 pods, 1 node → 2 nodes)        ║
║  • T+5min: Load drops, scale-down (3 pods → 2 pods)                  ║
║  • T+5min+30s: Consolidation (2 nodes → 1 node)                      ║
║                                                                       ║
║  KMAB Advantage:                                                      ║
║  ✓ Selected optimal instance (t3.small, not t3.medium)               ║
║  ✓ Rapid consolidation (30s detection + 30s cleanup)                 ║
║  ✓ Total waste: 86 MiB average (vs 300 MiB Docker Swarm)             ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
```

---

## DIAGRAM 4: Decision Tree for Each Phase

```
╔═══════════════════════════════════════════════════════════════════════╗
║                    PHASE 2 DECISION TREE                              ║
║                  (Bin-pack Optimization)                              ║
╚═══════════════════════════════════════════════════════════════════════╝

                  START: Unschedulable pod detected
                              │
                              ▼
                   Get pod memory request: r
                              │
                              ▼
        ┌─────────────────────┴─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
   t2.micro             t3.micro               t3.small
   (1024 MiB)           (1024 MiB)             (2048 MiB)
        │                     │                     │
        ▼                     ▼                     ▼
  fit = ⌊1024/r⌋        fit = ⌊1024/r⌋        fit = ⌊2048/r⌋
        │                     │                     │
        ▼                     ▼                     ▼
  waste = (1024-fit×r)/1024  │              waste = (2048-fit×r)/2048
        │                     │                     │
        ▼                     ▼                     ▼
  score = fit/(waste+0.001)  │              score = fit/(waste+0.001)
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                              │
                              ▼
                    Select argmax(score)
                              │
                              ▼
                    Optimal instance type
                              │
                              ▼
                      Go to PHASE 3


╔═══════════════════════════════════════════════════════════════════════╗
║                    PHASE 5 DECISION TREE                              ║
║                     (Consolidation)                                   ║
╚═══════════════════════════════════════════════════════════════════════╝

              Every 30 seconds
                    │
                    ▼
         For each active node
                    │
                    ▼
    Calculate: mem_util = used/allocatable
                    │
                    ▼
         Is mem_util < 30%?
                    │
        ┌───────────┴───────────┐
        │                       │
       YES                     NO
        │                       │
        ▼                       ▼
  Check if all pods        Node is busy
  can reschedule          Keep node active
        │                       │
        ▼                       └──→ Continue monitoring
  Can reschedule?
        │
        ┌───────────┴───────────┐
        │                       │
       YES                     NO
        │                       │
        ▼                       ▼
  CONSOLIDATE              Cannot consolidate
  • Cordon node            Keep node active
  • Drain pods                   │
  • Terminate EC2                └──→ Continue monitoring
        │
        ▼
  Node terminated
  Memory freed
        │
        ▼
  Continue monitoring
```

---

## DIAGRAM 5: Integration Points (How Phases Connect)

```
╔═══════════════════════════════════════════════════════════════════════╗
║                    KMAB INTEGRATION POINTS                            ║
║              (Why This Is More Than Configuration)                    ║
╚═══════════════════════════════════════════════════════════════════════╝


┌────────────────┐                    ┌────────────────┐
│   PHASE 4      │                    │   PHASE 2      │
│   HPA          │                    │   Bin-pack     │
│                │                    │                │
│ Creates pods   │                    │ YOUR MEMORY-   │
│ with EXPLICIT  │───────────────────→│ AWARE FORMULA  │
│ memory=128Mi   │  Integration 1     │ uses 128Mi in  │
│                │  (Pod specs feed   │ calculation    │
└────────────────┘   into scoring)    └────────────────┘
        │
        │
        │ Scales down pods
        │
        ▼
┌────────────────┐
│   PHASE 5      │
│   Consolidate  │
│                │
│ Detects low    │
│ memory (<30%)  │◀───────────────────┐
│ Terminates node│  Integration 2     │
└────────────────┘  (HPA triggers      │
        │            consolidation)    │
        │                              │
        │ Frees capacity               │
        │                              │
        ▼                              │
┌────────────────┐                     │
│   PHASE 1      │                     │
│   Observe      │                     │
│                │                     │
│ More capacity  │─────────────────────┘
│ available for  │  Integration 3
│ rescheduling   │  (Feedback loop)
└────────────────┘


KEY INSIGHT:
━━━━━━━━━━━
Standard Karpenter: Each phase operates independently
                    ↓
                  Memory wasted

KMAB: All 5 phases are COORDINATED with memory as primary metric
      ↓
    71% waste reduction
```

---

**END OF DIAGRAMS**

## How to Use These Diagrams:

1. **For Thesis:** Convert Diagram 1 to a full-page figure in your methodology chapter
2. **For Defense Presentation:** Use Diagram 3 (example scenario) to walk through a live demo
3. **For Paper Submission:** Use Diagram 2 (comparison) to show your contribution vs baseline
4. **For Committee Questions:** Keep Diagram 4 (decision trees) ready to explain algorithm details
5. **For Explaining Integration:** Use Diagram 5 to show why it's not just "configuration"

Convert these ASCII diagrams to visual diagrams using:
- draw.io (free)
- Microsoft Visio
- PowerPoint SmartArt
- LaTeX TikZ (for academic papers)
