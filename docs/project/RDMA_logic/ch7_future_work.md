# Section 7: Future Work

This section outlines logical next steps to evolve the proof-of-concept RDMA engine toward a production-quality system. The current design validates the core architectural principles; the extensions described here address concurrency, OS integration, and robustness requirements for deployment.

---

## 7.1 Pipelining and Overlapped Execution

The current implementation processes one work queue entry at a time, which limits throughput for small transfers. Pipelining would allow multiple execution stages to operate concurrently.

### Proposed Extensions

| Extension | Description |
|-----------|-------------|
| Multiple in-flight WQEs | Allow descriptor fetch, payload transfer, and completion writeback to overlap for different entries |
| Early SQ_HEAD advancement | Advance SQ_HEAD after descriptor acceptance rather than after CQ write |
| Completion reordering buffer | Track pending completions when execution order differs from submission order |

### Expected Impact

| Metric | Current | With Pipelining |
|--------|---------|-----------------|
| Operations in flight | 1 | N (configurable) |
| SQ_HEAD update timing | After CQ write | After descriptor fetch |
| Small block throughput | Overhead-dominated | Amortized overhead |

---

## 7.2 Multi-Queue Support

The architecture extends naturally to multiple queue pairs (QPs), enabling parallel operation and per-context isolation.

### Multi-QP Architecture

```
┌─────────────────────────────────────────────────┐
│ Multi-QP RDMA Engine                            │
│                                                 │
│  QP0: rdma_controller_0 → tx_streamer_0        │
│  QP1: rdma_controller_1 → tx_streamer_1        │
│  QP2: rdma_controller_2 → tx_streamer_2        │
│                                                 │
│  Shared: DataMover arbiter, DDR interface      │
└─────────────────────────────────────────────────┘
```

### Benefits

| Capability | Description |
|------------|-------------|
| Context isolation | Independent SQ/CQ pairs per application thread |
| Parallel execution | Multiple controllers operate concurrently |
| Multi-core scalability | Different CPU cores submit to different QPs without synchronization |

---

## 7.3 Linux Kernel Driver Integration

The current bare-metal polling interface is sufficient for validation but not suitable for OS deployment. A Linux driver would provide the standard interfaces required for application integration.

### Driver Architecture

| Component | Responsibility |
|-----------|----------------|
| Device exposure | Character device (`/dev/rdma0`) or UIO interface for user-space access |
| Register mapping | AXI-Lite registers mapped via `ioremap()` |
| Memory management | DMA-coherent buffer allocation; automatic cache coherency via Linux DMA API |
| User buffer handling | Page pinning (`get_user_pages()`) for zero-copy payload access |

### Completion Mechanisms

| Interface | Use Case |
|-----------|----------|
| Blocking wait | `read()`/`ioctl()` calls integrated with kernel wait queues |
| Non-blocking poll | Memory-mapped CQ access for low-latency workloads |
| Event notification | `epoll()`/`select()` support for event-driven applications |

### Interrupt Support

The current hardware produces well-defined completion events (CQ_TAIL advancement). Future hardware revisions could add interrupt generation on CQ_TAIL update, enabling interrupt-driven completion handling instead of polling.

---

## 7.4 Error Handling and Robustness

A production system requires explicit error detection and recovery mechanisms not present in the current proof-of-concept.

### Error Detection Extensions

| Category | Extension |
|----------|-----------|
| DMA errors | Monitor DataMover `mm2s_err` and `s2mm_err` outputs |
| Status propagation | Set CQ entry status field to error codes (0x01 = local error, 0x02 = remote error) |
| Address validation | Check addresses against configured DDR range before issuing DMA commands |

### Timeout Mechanisms

| State | Timeout Purpose |
|-------|-----------------|
| Descriptor fetch | Detect stalled MM2S read |
| Payload transfer | Detect stalled payload DMA |
| CQ write | Detect stalled S2MM write |

Timeout thresholds could be exposed as AXI-Lite registers for software configuration.

### Recovery Path

Upon error or timeout detection:

1. Set error status in CQ entry
2. Advance SQ_HEAD and CQ_TAIL to complete the failed operation
3. Optionally trigger interrupt for software notification
4. Return controller to idle state for next operation

---

## 7.5 Summary

| Extension | Complexity | Impact |
|-----------|------------|--------|
| Pipelining | Moderate | Higher throughput for small transfers |
| Multi-queue | Moderate | Parallel execution, context isolation |
| Linux driver | Moderate | OS integration, standard interfaces |
| Error handling | Low-Moderate | Production robustness |
| Interrupt support | Low | Reduced CPU polling overhead |

These extensions build upon the validated core architecture without requiring fundamental redesign of the descriptor-driven execution model or queue-based control interface.
