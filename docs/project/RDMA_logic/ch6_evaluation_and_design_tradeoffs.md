# Section 6: Evaluation and Design Trade-offs

This section evaluates the implemented RDMA loopback design from a functional and architectural perspective. The goal is not to benchmark performance or claim protocol completeness, but to assess whether the system correctly realizes the intended RDMA transaction semantics, and to clarify the design decisions and limitations inherent to the chosen architecture.

---

## 6.1 Functional Validation Summary

The primary objective of the loopback project was to validate the correctness of the RDMA transaction pipeline end-to-end, spanning software submission, hardware execution, data movement, and completion reporting. This objective was achieved through deterministic testing of the complete descriptor-to-completion flow.

Functional validation confirms that the following sequence operates correctly:

1. **Software Submission** (Section 5.7.1): Software constructs 64-byte SQ descriptors in DDR, flushes data cache lines to ensure visibility, and signals availability via SQ_TAIL register update, which generates an implicit doorbell pulse.

2. **Descriptor Fetch** (Section 5.2): The RDMA controller detects `SQ_HEAD ≠ SQ_TAIL`, fetches the descriptor via DataMover MM2S channel (64-byte read), and latches parsed fields (opcode, addresses, length, ID) into internal registers.

3. **Header Construction** (Section 5.3): The transmit path constructs a fixed 7-beat (28-byte) RDMA header containing PSN, opcode, destination QP, remote address, fragment offset, length, partition key, and service level fields, which is serialized ahead of payload data.

4. **Payload Transfer** (Section 5.4): Payload data is fetched from DDR via DataMover MM2S channel and streamed contiguously after the header, with TLAST asserted on the final payload beat to mark packet boundaries.

5. **Loopback Buffering** (Section 5.5.1): The combined header + payload stream traverses the AXI-Stream FIFO without loss or reordering, providing elastic buffering between TX and RX paths.

6. **Header Parsing** (Section 5.5.2-6.5.4): The receive path accumulates 7 header beats, extracts metadata fields when `beat_count=6`, and asserts a `header_valid` pulse to signal completion.

7. **Payload Write** (Section 5.5.6-6.5.7): The rx_streamer validates the opcode as a WRITE operation, computes the destination address as `remote_addr + fragment_offset`, and issues a DataMover S2MM command to write payload to DDR.

8. **Completion Generation** (Section 5.6): Upon transmission completion (`mm2s_rd_xfer_cmplt` detected), the controller populates an 8-word (32-byte) CQ entry with status, byte count, and WQE metadata, writes it to DDR via DataMover S2MM, and atomically increments both CQ_TAIL and SQ_HEAD pointers.

9. **Software Polling** (Section 6.7.2-6.7.4): Software detects completion by polling the read-only CQ_TAIL register, invalidates cache lines covering the CQ entry, reads completion metadata from DDR, verifies status and byte counts, and advances the CQ_HEAD register to free the slot.

Correctness was verified through:
- **Data integrity**: Bit-exact matching of transmitted and received payload buffers in DDR
- **Pointer progression**: Correct wraparound behavior of SQ_HEAD, SQ_TAIL, CQ_HEAD, and CQ_TAIL with modulo arithmetic
- **Metadata consistency**: CQ entry fields (WQE ID, bytes_sent, status=0) match the original SQ descriptor parameters

The implementation operates deterministically with no interrupt-driven execution or speculative paths. The rdma_controller FSM processes descriptors sequentially (one at a time), ensuring predictable behavior suitable for architectural validation. Software may post multiple descriptors to the SQ, but hardware consumes them serially, advancing SQ_HEAD only after each operation completes and its CQ entry is written (Section 5.6.5).

---

## 6.2 Rationale for the Loopback Architecture

The loopback architecture was a deliberate design choice to isolate and validate RDMA transaction mechanics independently of transport-layer complexity. By replacing Ethernet/IP/transport stacks with a simple AXI-Stream FIFO, the design enables focused validation of core RDMA semantics without the noise of protocol-specific corner cases.

The loopback design enables focused verification of:

- **Descriptor interpretation**: Correct parsing of 64-byte SQ entries into opcode, address, length, and metadata fields (Section 5.2.3)
- **Header construction**: Accurate serialization of 7-beat headers with proper field packing and beat ordering (Section 5.3.3)
- **AXI-Stream sequencing**: Enforcement of header-before-payload ordering, TLAST-based packet boundaries, and backpressure propagation (Section 5.3.4, 6.4.5)
- **DataMover coordination**: Correct usage of MM2S (descriptor fetch, payload read) and S2MM (CQ write, RX payload write) channels with 72-bit command format (Section 5.4.2)
- **Completion generation**: Accurate CQ entry population, atomic pointer updates, and software visibility through register polling (Section 5.6.5)
- **Cache coherency**: Proper use of flush/invalidate operations at PS-PL boundaries (Section 6.7.7)

By excluding Ethernet MAC, PHY, IP checksumming, and transport protocols, the design avoids introducing:
- Variable network latency and packet loss scenarios
- Protocol state machines (TCP/IP, RoCEv2 encapsulation)
- Asynchronous event handling (link-level flow control, congestion notification)
- External dependencies on network infrastructure

This isolation allows each pipeline stage to be debugged deterministically using ILA captures, waveform analysis, and software-side buffer inspection. Functional correctness can be established with high confidence before introducing transport complexity.

---

## 6.3 Limitations and DataMover-Centric Design Trade-offs

The implemented system intentionally omits several features commonly associated with production RDMA engines. These omissions reflect conscious scope decisions to maintain tractable complexity for proof-of-concept validation.

### 6.3.1 Architectural Limitations

**Completion Detection**:
- **Polling-based only**: No interrupt generation when CQ_TAIL advances. Software must busy-wait on CQ_TAIL reads (Section 6.7.2), consuming CPU cycles.
- **No CQ overflow detection**: Hardware does not check for `(CQ_TAIL + 1) mod CQ_SIZE == CQ_HEAD` before writing CQ entries. Software must ensure adequate CQ depth and polling frequency (Section 5.6.6).

**Concurrency and Pipelining**:
- **Sequential FSM**: The rdma_controller processes one descriptor at a time. SQ_HEAD advances only after the entire operation completes (descriptor fetch → payload transfer → CQ write). Software may post multiple descriptors, but hardware execution is serialized (Section 5.6.5).
- **No multi-queue support**: Single SQ/CQ pair only. No QP (Queue Pair) isolation or per-connection state.

**Error Handling**:
- **No error propagation**: The tx_streamer sets `tx_cpl_status = 0` unconditionally. DataMover error signals (`mm2s_err`, `s2mm_err`) are not monitored or reported in CQ entries (Section 5.4.7).
- **No timeout detection**: If DataMover stalls, the FSM waits indefinitely in WAIT_READ_DONE, WAIT_DM_STS, or WAIT_WRITE_DONE states. Software must implement watchdog timers (Section 5.2.7).

**Protocol Features**:
- **No retransmission or PSN progression**: PSN is fixed at `0x000001` for all packets. No ACK/NAK mechanism, no out-of-order handling (Section 5.3.1).
- **No protection domains or rkey validation**: The 7-beat header does not include an rkey field, and the RX path performs no authentication (Section 5.5.4 note).
- **No fragmentation reassembly on RX**: The rx_streamer writes each fragment independently based on `fragment_offset`, but does not track multi-fragment reassembly state or validate completion.

These constraints simplify the control logic and make functional validation tractable, at the cost of throughput, robustness, and feature completeness.

### 6.3.2 DataMover-Centric Design Trade-offs

A key architectural decision is the reliance on Xilinx AXI DataMover IP for all memory transfers (SQ fetch, payload read, CQ write, RX payload write). This choice has clear advantages and disadvantages:

**Advantages**:
- **Standards-compliant AXI behavior**: The DataMover implements correct AXI4 burst transactions, address alignment, and byte enable handling, reducing verification burden.
- **Reliable MM2S and S2MM channels**: Well-tested Xilinx IP with predictable command/status interfaces and completion signaling (`mm2s_rd_xfer_cmplt`, `s2mm_wr_xfer_cmplt`).
- **Clear separation of concerns**: The rdma_controller and streamers focus on RDMA semantics, delegating DMA mechanics to the DataMover.
- **Reduced custom logic**: No need to implement custom AXI master FSMs, burst computation, or address boundary checks.

**Disadvantages**:
- **Fragmentation logic required**: The tx_streamer must respect 1 KB address boundaries and BLOCK_SIZE limits, computing chunk lengths and issuing multiple MM2S commands for large payloads (Section 5.3.5). This increases FSM complexity.
- **Command latency overhead**: Each DataMover operation requires a command handshake, internal processing delay, and completion signaling. For small payloads, command overhead may dominate execution time.
- **Limited error visibility**: The DataMover's internal error conditions (address decode failures, timeout, FIFO overflow) are not fully exposed. The design monitors only the binary completion signals (Section 5.4.7).
- **Increased FSM state count**: Command issuance, status waiting, and completion detection require dedicated FSM states (S_READ_CMD, S_WAIT_READ_DONE, S_WRITE_CMD, S_WAIT_WRITE_DONE, etc.), expanding the controller's state space.

Despite these trade-offs, the DataMover-centric approach is well-suited for a proof-of-concept RDMA engine and aligns with SoC design best practices (reuse validated IP blocks, avoid reinventing DMA logic). For high-performance or multi-queue designs, the approach would require augmentation: custom DMA engines with pipelined command issuance, scatter-gather support, and direct error status propagation.


