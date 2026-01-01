# Section 5: Evaluation and Design Trade-offs

This section evaluates the implemented RDMA engine from a functional and architectural perspective, documents the engineering decisions made during development, and clarifies the limitations inherent to the chosen architecture. The evaluation covers both loopback-based validation (used for deterministic bring-up) and Ethernet-integrated operation (the primary deployment mode).

---

## 5.1 Functional Validation Summary

The primary objective of the project was to validate the correctness of the RDMA transaction pipeline end-to-end. This objective was achieved through deterministic testing of the complete descriptor-to-completion flow.

### Validated Capabilities

| Capability | Validation Method |
|------------|-------------------|
| Descriptor fetch and parsing | 64-byte SQ entries correctly interpreted |
| Header construction | 7-beat (28-byte) RDMA headers serialized with correct field packing |
| Payload transfer | Data streamed via DataMover with TLAST packet boundaries |
| Loopback integrity | Header + payload traverse FIFO without loss or reordering |
| RX header parsing | Metadata extracted, `header_valid` pulse asserted |
| Payload writeback | Data written to computed destination address |
| Completion generation | 32-byte CQ entries with correct status and byte counts |
| Pointer management | Correct wraparound behavior with modulo arithmetic |

### Correctness Criteria

- **Data integrity**: Bit-exact matching of transmitted and received payload buffers
- **Pointer progression**: SQ_HEAD, SQ_TAIL, CQ_HEAD, CQ_TAIL wrap correctly at queue boundaries
- **Metadata consistency**: CQ entry fields (WQE ID, bytes_sent, status=0) match original SQ descriptor

The implementation operates deterministically with no interrupt-driven execution or speculative paths, ensuring predictable behavior suitable for architectural validation.

---

## 5.2 Design Decisions

The following table summarizes key engineering decisions and their rationale:

| Decision | Chosen Approach | Alternative | Rationale |
|----------|-----------------|-------------|-----------|
| **Primary interface** | Ethernet (AXI 1G/2.5G + RGMII PHY) | Direct memory interconnect | Enables real network I/O; standard infrastructure compatibility |
| **Validation method** | Loopback FIFO (bring-up mode) | Ethernet-only testing | Isolates RDMA mechanics from transport complexity; deterministic debugging |
| **Packetization** | IP Encapsulator/Decapsulator | Custom frame format | Standard IP/UDP transport; interoperability with network tools |
| **Memory access** | Xilinx AXI DataMover IP | Custom AXI master FSM | Reduces verification burden; leverages validated IP; clear separation of concerns |
| **Execution model** | Sequential (one descriptor at a time) | Pipelined or parallel execution | Simplifies FSM; eliminates reordering; tractable for proof-of-concept |
| **Completion notification** | Polling-based | Interrupt-driven | Reduces complexity; sufficient for validation; no interrupt controller required |
| **Fragmentation** | TX-side 1 KB packetization | No fragmentation or RX reassembly | Respects Ethernet MTU constraints; defers reassembly complexity |
| **Error handling** | Status field reserved (always success) | Full error propagation | Scope limitation; error paths require additional FSM states and testing |
| **Queue model** | Single SQ/CQ pair | Multi-queue with QP isolation | Validates core mechanics; multi-queue adds significant state management |

### Staged Validation Rationale

The project employed a staged validation approach, using loopback mode during bring-up before transitioning to full Ethernet integration:

**Phase 1 — Loopback Validation**: An AXI-Stream FIFO routes TX output directly to RX input, bypassing Ethernet. This mode isolates RDMA mechanics from transport complexity, enabling focused verification of:

- Descriptor interpretation and field extraction
- Header serialization and AXI-Stream sequencing
- DataMover command/completion coordination
- Cache coherency at PS-PL boundaries

**Phase 2 — Ethernet Integration**: With RDMA semantics validated, the system was integrated with the AXI Ethernet Subsystem, IP Encapsulator/Decapsulator, and RGMII PHY for real network I/O.

The loopback path remains available for regression testing and debugging, allowing RDMA logic to be isolated from transport-layer effects when needed.

### Why Loopback Was Necessary

Loopback validation provided guarantees that Ethernet-only testing could not:

| Property | Loopback Guarantee | Ethernet Limitation |
|----------|-------------------|---------------------|
| Deterministic timing | Fixed latency, no jitter | PHY/MAC introduce variable delays |
| Isolated fault domain | RDMA logic only | Failures could be MAC, PHY, cabling, or RDMA |
| Repeatable throughput | Memory-bound, consistent | Network traffic and link conditions vary |
| Bit-exact validation | No frame transformations | CRC, padding, MAC operations modify data |
| Rapid iteration | No external dependencies | Requires connected network infrastructure |

By establishing correctness in loopback mode first, subsequent Ethernet integration failures could be confidently attributed to transport-layer issues rather than RDMA logic bugs.

---

## 5.3 Limitations

### Architectural Constraints

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| **Polling-only completion** | CPU busy-waits on CQ_TAIL | Software implements timeout; interrupt support is future work |
| **No CQ overflow detection** | Hardware may overwrite unread entries | Software must ensure adequate CQ depth and polling frequency |
| **Sequential execution** | Reduced throughput | Acceptable for validation; pipelining is future work |
| **No timeout detection** | FSM may stall indefinitely | Software watchdog required; hardware timeout is future work |

### Protocol Limitations

| Feature | Status | Notes |
|---------|--------|-------|
| Retransmission | Not implemented | PSN fixed; no ACK/NAK mechanism |
| Protection domains | Not implemented | No rkey validation on RX |
| Multi-fragment reassembly | Not implemented | RX writes fragments independently |
| Multi-queue support | Not implemented | Single SQ/CQ pair only |

### DataMover Trade-offs

**Advantages:**

- Standards-compliant AXI4 burst behavior
- Well-tested completion signaling
- Reduced custom logic and verification burden

**Disadvantages:**

- Fragmentation logic required for 1 KB boundaries
- Command latency overhead for small transfers
- Limited error visibility (binary completion only)
- Increased FSM state count for command/status handling

---

## 5.4 Scope Justification

The design decisions reflect a deliberate scope boundary balancing functionality with validation tractability:

| Included | Excluded | Justification |
|----------|----------|---------------|
| Ethernet TX/RX with IP/UDP packetization | Multi-endpoint routing | Single-endpoint validates end-to-end path |
| Complete TX/RX data path | Multi-endpoint communication | Loopback + Ethernet validates core mechanics |
| Queue-based submission/completion | Interrupt support | Polling sufficient for validation |
| Header construction/parsing | Reliability (PSN, ACK/NAK) | Deferred to future reliability layer |
| DataMover-based DMA | Custom scatter-gather | Leverages validated IP |
| Single-operation execution | Pipelined execution | Simplifies verification |
| Loopback validation mode | Always-on loopback | Loopback is bring-up tool, not deployment mode |

These constraints simplify control logic and make functional validation tractable while preserving all essential RDMA transaction semantics. The architecture provides a complete Ethernet-connected system that can be extended with pipelining, multi-queue support, and reliability mechanisms in future work.


