# Section 6: Results and Conclusion

This chapter presents the experimental results obtained from the RDMA engine, including loopback-based characterization and Ethernet-integrated validation. The results demonstrate correct operation across both validation modes and summarize conclusions regarding performance characteristics, architectural trade-offs, and system capabilities.

---

## 6.1 Experimental Setup

### Test Configuration

| Parameter | Value |
|-----------|-------|
| Payload size | Fixed at 1 MB |
| Block size | Varied from 32 bytes to 16 KB |
| Memory access | DDR via AXI DataMover exclusively |
| Completion model | Polling (no interrupts) |
| Timing method | Timestamp before SQ submission, after CQ completion |

**CPU Role:**

- Pre-initializes payload buffer in DDR with a monotonic counter
- Pre-writes SQ and CQ entries in memory
- Advances SQ_TAIL to submit work
- Polls CQ_TAIL to detect completion

**Validation Modes:**

| Mode | Transport Path | Purpose |
|------|----------------|--------|
| Loopback | TX → FIFO → RX (internal) | Deterministic throughput characterization |
| Ethernet | TX → MAC → PHY → Network → PHY → MAC → RX | End-to-end packet integrity validation |

The throughput measurements (Section 6.2) used loopback mode to isolate RDMA pipeline performance from network variability. Packet-level validation (Section 6.3) used Ethernet mode to confirm correct frame generation and real I/O operation.

The measured duration in loopback mode includes:

- Descriptor fetch and parsing
- Header insertion and payload DMA read (TX)
- Loopback streaming through FIFO
- Header parsing and payload DMA write (RX)
- CQ entry writeback and pointer update

---

## 6.2 Throughput Results

![RDMA Throughput vs Block Size](images/rdma_throughput_vs_block_size.jpg)
*Figure 6.1: Measured throughput (MB/s) as a function of block size for 1 MB payload transfers.*

### Observed Performance Regions

| Region | Block Size | Throughput | Limiting Factor |
|--------|------------|------------|-----------------|
| Small block | 32 B – 512 B | Low, slow increase | Per-operation overhead dominates |
| Transition | 1 KB – 4 KB | Sharp increase | Payload transfer begins to dominate |
| Saturation | ≥ 8 KB | ~950–1000 MB/s | DDR/interconnect bandwidth limit |

**Small Block Regime**: Throughput is limited by fixed costs (descriptor fetch, header processing, completion writeback) that cannot be amortized over small payloads.

**Transition Region**: DMA efficiency improves as payload size increases. Control-plane overhead is amortized across more data.

**Saturation Region**: The system reaches the practical bandwidth limit of the memory subsystem. The RDMA data path successfully drives DDR close to its sustainable throughput.

---

## 6.3 Packet-Level Validation (Ethernet Mode)

Packet correctness was validated via the Ethernet interface using Wireshark captures on an external host. This confirms correct IP Encapsulator operation, Ethernet MAC framing, and end-to-end packet delivery.

### Packet Reception

![Wireshark 4 Packets Received](images/wireshark_ss_4_packet_received.jpeg)
*Figure 6.2: Wireshark capture showing successful reception of 4 RDMA packets over Ethernet without loss.*

### Packet Structure

![RDMA Packet Header and Payload](images/wireshark_ss_rdma_package_header_and_payload.jpeg)
*Figure 6.3: Detailed view of a single Ethernet frame containing RDMA payload with correct UDP/IP encapsulation.*

### Payload Inspection

![Wireshark Payload View](images/wireshark_ss_payload.jpeg)
*Figure 6.4: RDMA packet showing 7-beat header followed by payload data with correct field serialization.*

These captures confirm that the IP Encapsulator correctly wraps RDMA payloads in standard Ethernet/IP/UDP frames, enabling interoperability with standard network analysis tools and infrastructure.

---

## 6.4 Conclusion

This project demonstrates a complete Ethernet-connected RDMA engine implemented in FPGA logic. The system was developed using a staged validation approach: loopback mode for deterministic verification of RDMA semantics, followed by Ethernet integration for real network I/O.

### Key Results

| Metric | Outcome |
|--------|--------|
| Functional correctness | Validated via data integrity and pointer progression (loopback mode) |
| Ethernet integration | Confirmed via Wireshark packet captures over real network |
| Throughput scaling | Predictable increase with block size |
| Peak throughput | ~1000 MB/s (approaches memory system limit) |
| Packet integrity | Confirmed via capture analysis |


