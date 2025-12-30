# RDMA Loopback Engine for FPGA-Based SoC

## 1. Introduction

**Remote Direct Memory Access (RDMA)** is a communication paradigm that enables direct data transfer between the memory spaces of endpoints with minimal CPU involvement. Unlike traditional network stacks, RDMA offloads data movement, segmentation, and completion handling to dedicated hardware, allowing applications to achieve:

- **Low latency** through kernel bypass
- **High throughput** via zero-copy data transfers
- **Predictable performance** with explicit completion semantics

RDMA is widely deployed in high-performance computing (HPC), data center networking, and storage systems where these characteristics are critical.

---

## RDMA Protocol Landscape

Several RDMA-capable transport protocols are deployed in practice today:

- **InfiniBand**: Native RDMA fabric with tightly specified semantics and hardware-managed reliability. Provides the lowest latency but requires dedicated infrastructure.

- **RoCE (RDMA over Converged Ethernet)**: Enables RDMA semantics on Ethernet networks, relying on lossless fabric assumptions (typically via Priority Flow Control). Offers a balance between performance and infrastructure reuse.

- **iWARP**: Implements RDMA over TCP, trading some performance for routability and compatibility with existing Ethernet infrastructure. Provides reliable delivery without requiring lossless Ethernet.

Despite differences in transport mechanisms, all RDMA protocols share a **common programming model** based on queue pairs, work queue elements, and completion queues.

---

## RDMA vs. Traditional TCP/IP Communication

Compared to conventional TCP/IP-based communication, RDMA offers key architectural advantages:

| **Aspect** | **TCP/IP** | **RDMA** |
|------------|-----------|----------|
| **CPU Involvement** | High (system calls, protocol processing) | Minimal (hardware offload) |
| **Data Copies** | Multiple (user ↔ kernel buffers) | Zero-copy (direct memory access) |
| **Latency** | Higher (context switches, buffering) | Lower (kernel bypass) |
| **Completion Model** | Implicit (socket ready events) | Explicit (completion queue entries) |
| **Predictability** | Variable (depends on OS scheduling) | Deterministic (hardware-driven) |

**Key RDMA Benefits:**

1. **Kernel Bypass**: Eliminates system calls and data copies between user and kernel space, reducing overhead on the data path.

2. **Zero-Copy Transfers**: Network or DMA engines read from and write to application memory directly, avoiding intermediate buffering.

3. **Explicit Completion Semantics**: Software can reason precisely about when data movement has finished through hardware-generated completion queue entries.

In contrast, TCP prioritizes reliability and generality but incurs higher latency and CPU overhead due to protocol processing, buffering, and context switches.

---

## Project Objectives

The goal of this project is **not** to implement a full standards-compliant RDMA stack or to compete with production-grade NICs. Instead, the objective is to:

**Design and validate a hardware-centric RDMA-style data path on an FPGA-based SoC**, focusing on the core mechanisms that make RDMA efficient:

- ✅ **Descriptor-driven execution**: Software submits work via memory-mapped queue structures
- ✅ **DMA-based data movement**: Hardware DataMover IP orchestrates memory transfers
- ✅ **Explicit completion reporting**: Completion queue entries provide status visibility
- ✅ **Clear hardware–software contract**: Well-defined register interface and memory formats

---

## Design Philosophy: Loopback Architecture

To keep the design **tractable and verifiable**, the project adopts a **loopback architecture** in which transmitted packets are routed directly back into a receive pipeline on the same device.

### What is Included

- ✅ Submission Queue (SQ) and Completion Queue (CQ) management
- ✅ Descriptor fetch and parsing
- ✅ RDMA header construction (7-beat custom format)
- ✅ DataMover-controlled payload transfers (MM2S and S2MM)
- ✅ Header insertion and parsing logic
- ✅ Completion generation and pointer management
- ✅ Software polling interface via AXI-Lite registers

### What is Intentionally Excluded

- ❌ Ethernet framing, MAC/PHY integration
- ❌ Congestion control and flow control mechanisms
- ❌ Retransmission and reliability protocols (ACK/NAK)
- ❌ PSN progression and out-of-order handling
- ❌ Remote key authentication and protection domains
- ❌ Interrupt-driven completion notification

This **separation of concerns** allows the design to concentrate on the **internal RDMA mechanics**—submission queues, completion queues, header insertion and parsing, and DataMover-controlled memory transfers—without conflating them with network-specific concerns.

---

## System Overview

The resulting system serves as a **proof-of-concept RDMA engine** that demonstrates an end-to-end transaction lifecycle:

```
Software Submission → Descriptor Fetch → Header Construction → 
Payload Transfer → Loopback FIFO → Header Parsing → 
Payload Write → Completion Generation → Software Polling
```

The design is:

- **Transparent**: All hardware state is visible through registers and memory structures
- **Deterministic**: Sequential FSM execution with no speculative or concurrent operations
- **Verifiable**: Loopback architecture enables bit-exact validation of transmitted and received data
- **Suitable for analysis**: Clean separation between control plane (registers, queues) and data plane (headers, payloads)

This foundation provides a validated platform for understanding RDMA hardware/software co-design principles and can serve as a stepping stone toward a full transport-backed RDMA implementation.

---

## Target Platform

- **Hardware**: AMD Kria KR260 (Zynq UltraScale+ MPSoC)
  - Processing System: ARM Cortex-A53 quad-core
  - Programmable Logic: FPGA fabric for RDMA controller and data path
  - Memory: DDR4 for queue structures and payload buffers
  
- **Software**: Bare-metal application (no OS)
  - Direct register access via memory-mapped I/O
  - Explicit cache management (flush/invalidate operations)
  - Polling-based completion detection

---

**Next**: See [Section 2: System Overview](documentation_section_2.md) for high-level architecture and design principles.