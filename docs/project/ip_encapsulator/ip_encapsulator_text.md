# IP Encapsulator – Design and Working Principle

## 1. Overview

The **IP Encapsulator** is a hardware IP core designed to construct complete Ethernet/IPv4/UDP frames from a streaming payload and associated per-packet metadata. It accepts payload data via AXI-Stream, sideband metadata describing network parameters, performs header generation and endpoint lookup using BRAM, and outputs fully encapsulated frames on an AXI-Stream interface.

The design is fully streaming, backpressure-aware, and suitable for integration into FPGA-based networking pipelines.

---

## 2. Top-Level Architecture

At a high level, the design consists of the following functional blocks:

- **Metadata alignment**
- **Length calculation**
- **Endpoint lookup (BRAM-based)**
- **Header generation (Ethernet, IPv4, UDP)**
- **Header and payload packing**
- **Statistics counters**
- **AXI-Lite control and status registers**
- **ACK side-channel handling**

All datapath modules communicate using valid/ready handshakes to ensure correct flow control.

---

## 3. Interfaces

### 3.1 AXI-Stream Payload Input (`s_axis_*`)

- Carries packet payload data.
- Supports `tkeep` and `tlast` for byte-level validity and packet boundaries.
- Backpressure is applied via `s_axis_tready`.

### 3.2 Metadata Sideband Interface (`meta_*`)

- One metadata beat per packet.
- Contains payload length, IP addresses, ports, flags, and endpoint ID.
- Metadata is aligned with the first payload beat before entering the processing pipeline.

### 3.3 AXI-Stream Frame Output (`m_axis_*`)

- Outputs complete Ethernet frames.
- Headers and payload are streamed sequentially.
- Proper `tkeep` and `tlast` semantics are preserved.

### 3.4 BRAM Interface (Port B)

- Used by the endpoint lookup module.
- Stores destination IP → MAC address mappings.
- Accessed synchronously.

### 3.5 AXI-Lite Control/Status Interface

- Used for configuration, monitoring, and control.
- Exposes packet counters, error flags, and configuration registers.

### 3.6 ACK Side-Channel Interface

- Stores and forwards acknowledgment information.
- Allows a single outstanding ACK until software or logic consumes it.

---

## 4. Metadata Alignment (`meta_align`)

The metadata and payload arrive on independent interfaces. The `meta_align` module ensures:

- Metadata is captured **before** payload transmission begins.
- Metadata is presented exactly once, aligned with the **first payload beat**.
- Payload beats are forwarded without modification.

### Operation Summary
1. Wait for metadata.
2. Wait for first payload beat.
3. Emit metadata alongside the first payload beat.
4. Stream remaining payload beats transparently.

This guarantees that all downstream modules receive consistent per-packet context.

---

## 5. Length Calculation (`length_calc`)

The `length_calc` module computes protocol length fields:

- **UDP length** = 8 + payload length
- **IP total length** = 20 + UDP length

### Key Properties
- One-beat input per packet.
- Holds output valid until accepted.
- Ensures header generators and packet counters see consistent lengths.

---

## 6. Endpoint Lookup (`endpoint_lookup`)

The endpoint lookup module translates a destination IP address into:

- Destination MAC address
- Source MAC address

### BRAM Entry Format
Each BRAM entry contains:
- Valid bit
- Stored destination IP
- Destination MAC
- Source MAC

### Lookup Flow
1. Hash destination IP to generate BRAM index.
2. Issue synchronous BRAM read.
3. Validate entry and compare stored IP.
4. Output MAC addresses or signal lookup error.

Lookup misses and hash collisions are flagged via `lookup_error`.

---

## 7. Header Generation

### 7.1 Ethernet Header (`eth_header`)

- Builds a 14-byte Ethernet header:
  - Destination MAC
  - Source MAC
  - EtherType = IPv4 (0x0800)
- Holds the header until downstream logic accepts it.

---

### 7.2 IPv4 Header (`ipv4_header_builder`)

- Generates a 20-byte IPv4 header.
- Computes header checksum combinatorially.
- Uses:
  - Configurable TTL
  - Protocol = UDP
  - Auto-incrementing Identification field

The header is emitted once per packet and held valid until consumed.

---

### 7.3 UDP Header (`udp_header`)

- Generates an 8-byte UDP header:
  - Source port
  - Destination port
  - Length
  - Checksum (set to zero)

Uses a simple valid/ready handshake and emits exactly one header per packet.

---

## 8. Header Packing and Frame Emission (`header_packer`)

The `header_packer` module is responsible for:

- Concatenating Ethernet, IPv4, and UDP headers
- Padding headers to align with data width
- Streaming headers followed by payload data
- Generating correct `tkeep` and `tlast` signals

### State Machine
- **IDLE**: Waits for all headers and length info.
- **HEADERS**: Streams header beats.
- **PAYLOAD**: Forwards payload beats.

This module ensures that frames are emitted as a single continuous AXI-Stream packet.

---

## 9. Flow Control Strategy

The design uses **end-to-end backpressure propagation**:

- Metadata readiness depends on all downstream header generators being ready.
- Payload backpressure propagates upstream via AXI-Stream ready signals.
- Headers are only generated when downstream consumers can accept them.

This guarantees no data loss and correct packet framing under congestion.

---

## 10. Statistics Collection (`stats_regs`)

The statistics module tracks:

- Packet count
- Byte count (based on IP total length)

Counters increment when a packet’s final beat is successfully transmitted. Counters can be cleared via AXI-Lite.

---

## 11. AXI-Lite Register Block (`axi_lite_regs`)

### Control Registers
- Enable
- Loopback
- Counter clear pulse
- Interrupt enable

### Status Registers
- Ready indication
- Sticky lookup error flag
- IRQ pending flag

### Counters
- Packet count (64-bit)
- Byte count (64-bit)

### Queue and BRAM Configuration
- BRAM base and size
- Submission and completion queue pointers

Interrupts are level-triggered and cleared via explicit acknowledgment.

---

## 12. ACK Side-Channel Logic

A simple register captures incoming ACK information:

- Only one ACK may be stored at a time.
- New ACKs are accepted only when the previous one is cleared.
- Software or logic acknowledges consumption via `ack_is_read`.

This provides a lightweight asynchronous notification mechanism.

---

## 13. Reset and Clocking

- All modules are synchronous to a single clock.
- Active-low reset (`rstn`) clears all state.
- BRAM clock is tied to the system clock.

---

## 14. Summary

This IP encapsulator provides a modular, streaming-capable solution for packet encapsulation in FPGA-based network systems. The design cleanly separates concerns such as metadata handling, lookup, header generation, and frame packing, making it scalable, maintainable, and easy to extend (e.g., checksum offload, VLAN tagging, or IPv6 support).

---
