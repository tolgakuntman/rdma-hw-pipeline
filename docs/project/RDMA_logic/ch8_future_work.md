# Section 8: Future Work

The RDMA engine developed in this project validates the core architectural principles of **descriptor-driven execution**, **DMA-based data movement**, and **explicit completion reporting**. While the fundamental data path and control mechanisms are in place, several extensions are required to evolve the design toward a more complete and usable system.

This section outlines concrete directions for future work, focusing on:
- Concurrency and parallelism
- Software integration (Linux kernel driver)
- Robustness and error handling
- Memory protection and security

---

## 8.1 Parallelism and Multi-Queue Support

The current implementation processes **one work queue entry at a time** using a single rdma_controller FSM. While this simplifies correctness and verification, it limits throughput for small block sizes and prevents full utilization of the memory subsystem.

### Pipelining and Overlapped Execution

Future work could introduce **overlapped operation execution**, allowing multiple stages to operate concurrently:

**Support for multiple in-flight WQEs**  
Allow descriptor fetch, payload transfer, and completion writeback to overlap for different work queue entries.

**Early SQ_HEAD advancement**  
Advance SQ_HEAD after descriptor acceptance rather than waiting for full completion, freeing SQ slots faster.

#### Benefits

| **Aspect** | **Current** | **With Pipelining** |
|------------|-------------|---------------------|
| **Operations in flight** | 1 | N (configurable) |
| **SQ_HEAD update** | After CQ write | After descriptor fetch |
| **Small block throughput** | Low (overhead-dominated) | Higher (amortized overhead) |
| **Complexity** | Minimal | Moderate (reordering logic) |

---

### Multi-Queue and Queue Pair Support

The architecture naturally extends to **multiple queue pairs (QP instances)**:

**Independent SQ/CQ pairs per software context**  
Each application thread or process gets its own dedicated queue pair, eliminating contention.

**Parallel TX/RX pipelines**  
Multiple RDMA controllers can operate concurrently, each managing a separate QP.

**Improved scalability on multi-core systems**  
Different CPU cores can submit work to different QPs without synchronization overhead.

#### Implementation Approach

```
┌─────────────────────────────────────────────────┐
│ Multi-QP RDMA Engine                            │
│                                                 │
│  QP0: rdma_controller_0 → tx_streamer_0        │
│  QP1: rdma_controller_1 → tx_streamer_1        │
│  QP2: rdma_controller_2 → tx_streamer_2        │
│  ...                                            │
│                                                 │
│  Shared: DataMover arbiter, DDR interface      │
└─────────────────────────────────────────────────┘
```

---

## 8.2 Linux Kernel Driver and OS Integration

The current software interface is implemented as **bare-metal polling code**, which is sufficient for validation but not suitable for deployment in a general-purpose operating system. A critical next step is the development of a **Linux kernel driver** for the RDMA engine.

---

### Device Driver Responsibilities

A Linux driver would provide:

#### 1. Device Exposure

**Character device or UIO (Userspace I/O) interface**  
Expose the RDMA engine to user-space applications via `/dev/rdma0` or similar.

**Register mapping**  
Map AXI-Lite control registers into kernel virtual address space using `ioremap()`.

**Sysfs attributes**  
Expose queue configuration, status registers, and statistics via `/sys/class/rdma/`.

---

#### 2. Memory Management

**DMA-coherent buffer allocation**  
Manage SQ and CQ memory allocation using `dma_alloc_coherent()` to ensure cache coherency.

**Transparent cache management**  
Handle cache flush/invalidate operations automatically using the Linux DMA API (`dma_map_single()`, `dma_unmap_single()`).

**Page pinning for user buffers**  
Use `get_user_pages()` to pin user-space payload buffers in memory for direct DMA access.

---

#### 3. Completion Mechanisms

**Blocking wait interface**  
Provide `read()` or `ioctl()` calls that block until completions are available, integrated with `wait_queue`.

**Non-blocking polling interface**  
Allow user-space to poll CQ entries directly via memory-mapped I/O for low-latency workloads.

**Asynchronous notification**  
Support `select()`/`poll()`/`epoll()` for event-driven applications.

---

### Interrupt-Based Completion Handling

Although the current hardware does not generate interrupts, the design already produces **well-defined completion events** (CQ_TAIL advancement). Future hardware revisions could add interrupt support.

---

## 8.3 Error Handling, Timeouts, and Robustness

The current implementation assumes **ideal conditions**: valid addresses, reliable DMA execution, and forward progress. A production-ready system would require **explicit error detection and recovery mechanisms**.

---

### Error Detection Extensions

#### 1. DataMover Error Monitoring

**Monitor AXI DataMover error outputs**  
Check `mm2s_err` and `s2mm_err` signals for decode errors, slave errors, or timeout conditions.

**Propagate DMA errors to CQ status**  
Set CQ entry status field to error codes (e.g., 0x01 = local memory error, 0x02 = remote memory error).


---

#### 2. Timeout Detection

**Add timeout counters for stalled operations**  
Implement watchdog timers in FSM states:
- S_WAIT_READ_DONE (descriptor fetch timeout)
- S_WAIT_DM_STS (payload transfer timeout)
- S_WAIT_WRITE_DONE (CQ write timeout)

**Configurable timeout thresholds**  
Expose timeout values as AXI-Lite registers, allowing software tuning.
