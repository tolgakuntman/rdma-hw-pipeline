# Section 2: System Overview

This section presents a high-level overview of the RDMA engine system, its major components, and the design principles that guide the overall architecture. Detailed control flow, data path behavior, and register-level interfaces are described in later sections.

---

## 2.1 Design Objectives

The system is designed with the following core principles:

### Primary Objectives

**Hardware-driven data movement**  
All payload transfers are performed by data movers in the PL, without CPU involvement on the data path. Software submits work but does not touch payload bytes.

**Explicit queue-based control model**  
Software interacts with hardware exclusively through submission and completion queues in DDR memory, following industry-standard RDMA semantics.

**Deterministic execution flow**  
One work request is processed at a time by a single controller FSM, ensuring precise ordering and easy verification. No concurrent operations or speculative execution.

**Minimal protocol scope**  
Only the essential RDMA mechanisms are implemented. Transport-layer features (retransmission, congestion control) are intentionally excluded for clarity.

**Verifiability and traceability**  
Every observable software-visible event (e.g., SQ_HEAD or CQ_TAIL update) corresponds to a clearly defined hardware state transition, enabling precise debugging.

---

## 2.2 Top-Level System Composition

The system comprises six functional domains that interact through well-defined interfaces:

### 1. Processing System (PS) — ARM Cortex-A53

**Responsibilities:**
- Run bare-metal software application
- Prepare 64-byte work descriptors in DDR
- Manage queue pointers via memory-mapped AXI-Lite registers
- Poll for completions and verify results
- Perform explicit cache flush/invalidate operations

**Interface:** AXI-Lite register access, cache-coherent DDR access

---

### 2. RDMA Controller (PL) — Control Plane FSM

The global coordinator that manages submission and completion queues, orchestrates data movement, and owns all queue pointers (SQ_HEAD, CQ_TAIL). See [Section 3](ch3_hardware_architecture.md) for detailed implementation.

---

### 3. Transmit Data Path (PL) — Header + Payload Streaming

Converts SQ descriptors into RDMA packets by constructing headers, reading payloads from DDR, and streaming the combined data. Handles fragmentation for transfers exceeding 4 KB boundaries. See [Section 3.3](ch3_hardware_architecture.md#33-transmit-path-tx) for detailed implementation.

---

### 4. Loopback FIFO (PL) — Elastic Buffering

A Xilinx AXI-Stream FIFO that routes transmitted packets directly back to the receive path. This enables self-contained validation without external networking, preserving packet boundaries and handling backpressure between TX and RX paths.

---

### 5. Receive Data Path (PL) — Header Parsing + Payload Write

Parses incoming RDMA packets, extracts metadata from headers, and writes payloads to DDR at computed destination addresses. Operates independently from the RDMA controller. See [Section 3.4](ch3_hardware_architecture.md#34-receive-path-rx) for detailed implementation.

---

### 6. Shared DDR Memory — Queue Structures and Payload Buffers

Hosts submission queue (SQ) descriptors, completion queue (CQ) entries, and payload buffers. The PS accesses memory through a cache-coherent path (requiring explicit flush/invalidate), while the PL uses non-coherent DMA via [DataMover](https://www.xilinx.com/support/documents/ip_documentation/axi_datamover/v5_1/pg022_axi_datamover.pdf). See [Section 3.2](ch3_hardware_architecture.md#32-queue-management-blocks-sq-and-cq) for queue structure details.

---

## 2.3 Control Plane vs. Data Plane Separation

A key architectural decision is the **strict separation** between control plane and data plane responsibilities:

- **Control Plane** (RDMA controller): Manages descriptor lifecycle, queue pointers, operation sequencing, and completion generation
- **Data Plane** (TX/RX streamers, [DataMover](https://www.xilinx.com/support/documents/ip_documentation/axi_datamover/v5_1/pg022_axi_datamover.pdf)): Moves bytes between DDR and AXI-Stream, handles headers and backpressure

This separation ensures control overhead does not block data throughput. See [Section 3](ch3_hardware_architecture.md) for detailed ownership boundaries.

---

## 2.4 Descriptor-Driven Execution Model

All operations are initiated by **software-posted descriptors** residing in DDR. The hardware **never speculates** or generates work autonomously.

### Execution Pipeline

Once the SQ_TAIL pointer is advanced by software, the descriptor becomes visible to hardware and progresses through a **strictly ordered execution pipeline**:

```
1. Fetch   → Read 64-byte SQ entry from DDR
2. Parse   → Extract fields into internal registers
3. Execute → TX streamer reads payload, constructs packet, streams to FIFO
4. Complete → Write 32-byte CQ entry to DDR, update SQ_HEAD and CQ_TAIL
```

This model mirrors the execution semantics of production RDMA devices while remaining **fully transparent** to software and debug tools.

---

## 2.5 Single-Operation Execution Policy

The current design processes **one work request at a time**. The RDMA controller does not fetch a new SQ entry until:

1. The current payload transmission has completed (`mm2s_rd_xfer_cmplt` detected)
2. The corresponding CQ entry has been written to DDR (`s2mm_wr_xfer_cmplt` detected)
3. SQ_HEAD and CQ_TAIL pointers have been updated atomically

### Trade-offs

**Advantages:**
- Eliminates reordering and race conditions
- Simplifies completion correlation (1:1 SQ entry → CQ entry)
- Makes hardware/software interaction easy to verify
- Deterministic behavior suitable for functional validation

**Limitations:**
- Reduced throughput (no pipelining of multiple operations)
- Single-threaded execution (FSM idle between operations)

This conservative policy is a **deliberate trade-off** aligned with the project's architectural validation goals. Software may post multiple descriptors to the SQ, but hardware processes them sequentially.

