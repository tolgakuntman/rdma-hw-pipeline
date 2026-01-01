# RDMA Engine for FPGA-Based SoC

## 1. Introduction

**Remote Direct Memory Access (RDMA)** is a communication paradigm that enables direct data transfer between the memory spaces of networked endpoints with minimal CPU involvement. Unlike traditional network stacks where the processor must actively participate in data movement, RDMA offloads the entire transfer operation to dedicated hardware. This architectural shift provides three fundamental advantages:

- **Low latency** through kernel bypass
- **High throughput** via zero-copy data transfers
- **Predictable performance** with explicit completion semantics


---

## State-of-the-Art RDMA Protocols

Several RDMA-capable transport protocols are deployed in practice today:

- **InfiniBand**: Native RDMA fabric with tightly specified semantics and hardware-managed reliability. Provides the lowest latency but requires dedicated infrastructure.

- **RoCE (RDMA over Converged Ethernet)**: Enables RDMA semantics on Ethernet networks, relying on lossless fabric assumptions (typically via Priority Flow Control). Offers a balance between performance and infrastructure reuse.

- **iWARP**: Implements RDMA over TCP, trading some performance for routability and compatibility with existing Ethernet infrastructure. Provides reliable delivery without requiring lossless Ethernet.

Despite differences in transport mechanisms, all RDMA protocols share a **common programming model** based on queue pairs and work queue elements.

---

## RDMA vs. Traditional TCP/IP Communication

![TCP/IP vs RDMA Architecture](images/tcp-ip-vs-rdma.jpeg)

Compared to conventional TCP/IP-based communication, RDMA provides key architectural advantages:

| **Aspect** | **TCP/IP** | **RDMA** |
|------------|-----------|----------|
| **CPU Involvement** | High (system calls, protocol processing) | Minimal (hardware offload) |
| **Data Copies** | Multiple (user-kernel buffer transitions) | Zero-copy (direct memory access) |
| **Latency** | Higher (context switches, buffering) | Lower (kernel bypass) |
| **Completion Model** | Implicit (socket readiness events) | Explicit (completion queue entries) |
| **Predictability** | Variable (OS scheduling dependent) | Deterministic (hardware-driven) |

**Key RDMA Benefits:**

1. **Kernel Bypass**: Eliminates system calls and data copies between user and kernel space, reducing overhead on the data path.

2. **Zero-Copy Transfers**: Network or DMA engines read from and write to application memory directly, avoiding intermediate buffering.

3. **Explicit Completion Semantics**: Software can reason precisely about when data movement has finished through hardware-generated completion queue entries.

In contrast, TCP prioritizes reliability and generality but incurs higher latency and CPU overhead due to protocol processing, buffering, and context switches.

---

## Why Not Use Existing Protocols?

While InfiniBand, RoCE, and iWARP are mature and widely deployed, each introduces complexity that exceeds the scope of this project:

- **InfiniBand** requires specialized host channel adapters and dedicated switch infrastructure not available in typical development environments.

- **RoCE** depends on lossless Ethernet configurations (PFC, ECN) that require compatible switch infrastructure and add network management complexity.

- **iWARP** demands a full TCP/IP stack implementation with associated state management, congestion control, retransmission logic, and reliability mechanisms.

By implementing a simplified RDMA-style engine with a custom header format, this project isolates the core concepts that make RDMA efficient—queue-based work submission, hardware-driven data movement, and explicit completion signaling—without the burden of protocol compliance. This approach enables a clearer understanding of the fundamental hardware-software interactions underlying RDMA architectures.

---

## Project Objectives

The goal of this project is **not** to implement a full standards-compliant RDMA stack or to compete with production-grade NICs. Instead, the objective is to **design and validate a hardware-centric RDMA-style data path on an FPGA-based SoC**, focusing on the core mechanisms that make RDMA efficient:

- **Queue-based work submission**: Software posts work requests to memory-resident queue structures that hardware consumes autonomously.
- **Hardware-driven data movement**: Dedicated DMA engines transfer payload data without CPU involvement on the data path.
- **Explicit completion reporting**: Hardware generates completion entries that software can poll to determine transfer status.
- **Defined hardware-software contract**: A clear interface between software and hardware through memory-mapped structures and registers.

---

## System Architecture: Ethernet-Connected RDMA Engine

The final system architecture integrates the RDMA engine with a complete Ethernet I/O path:

- **Network Interface**: AXI 1G/2.5G Ethernet Subsystem with RGMII PHY
- **Packetization**: IP/UDP encapsulation via custom IP Encapsulator and Decapsulator modules
- **Data Path**: AXI-Stream TX/RX glue logic connecting RDMA pipelines to the Ethernet MAC

This architecture enables real network I/O with external endpoints, supporting standard Ethernet frames carrying RDMA payloads over IP/UDP transport.

---

## Staged Validation: Loopback as a Bring-Up Mechanism

The project employs a **staged approach** where an internal loopback path was used during development to validate RDMA semantics before Ethernet integration.

In loopback mode, transmitted packets are routed back into the receive pipeline on the same device via an AXI-Stream FIFO, bypassing the Ethernet MAC and PHY. 

The loopback path remains available as an optional validation mode for regression testing and bring-up diagnostics. It validated the complete RDMA transaction lifecycle—descriptor processing, header serialization, payload DMA, and completion reporting—establishing correctness before Ethernet integration.

---

## Target Platform

- **Hardware**: AMD Kria KR260 (Zynq UltraScale+ MPSoC)
    - Processing System: ARM Cortex-A53 quad-core application processor
    - Programmable Logic: FPGA fabric hosting the RDMA controller and data path
    - Memory: DDR4 for queue structures and payload buffers

- **Software**: Bare-metal application (no operating system)
    - Direct hardware access via memory-mapped I/O
    - Polling-based completion detection

