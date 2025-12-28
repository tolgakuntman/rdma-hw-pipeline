# Ethernet RX Parser

## 1. Introduction

The `ethernet_rx_parser` module implements the receive-side (RX) datapath of an
Ethernet/IPv4/UDP processing pipeline. Its primary function is to accept raw
Ethernet frames from a MAC, parse and validate protocol headers, strip those
headers, and forward only the UDP payload on an AXI-Stream interface.

This module is designed to complement a TX-side IP encapsulator and enables
bidirectional UDP communication in FPGA-based network systems.

---

## 2. Functional Overview

For each incoming Ethernet frame, the RX parser performs the following steps:

1. Receive a complete Ethernet frame via AXI-Stream
2. Parse the Ethernet header and validate the EtherType
3. Parse the IPv4 header and validate version and protocol
4. Parse the UDP header and compute payload length
5. Forward the UDP payload only
6. Drop unsupported or malformed packets safely

The design is fully streaming, uses no internal FIFOs, and relies entirely on
AXI-Stream valid/ready handshaking for flow control.

---

## 3. Supported Packet Format

The module assumes the following fixed packet structure:

- Ethernet Header (14 bytes)
    - Destination MAC (6 bytes)
    - Source MAC (6 bytes)
    - EtherType (2 bytes = 0x0800)
- IPv4 Header (20 bytes)
- UDP Header (8 bytes)
- UDP Payload (N bytes)

---

## 4. Interfaces

### 4.1 AXI-Stream Input (Ethernet Frame)

| Signal | Description |
|------|-------------|
| `s_axis_tdata` | Raw Ethernet frame data |
| `s_axis_tkeep` | Byte-valid mask |
| `s_axis_tvalid` | Input data valid |
| `s_axis_tready` | Backpressure to MAC |
| `s_axis_tlast` | End of Ethernet frame |

The input stream provides the full Ethernet frame, including all headers and
payload.

---

### 4.2 AXI-Stream Output (UDP Payload)

| Signal | Description |
|------|-------------|
| `m_axis_tdata` | UDP payload data only |
| `m_axis_tkeep` | Byte-valid mask |
| `m_axis_tvalid` | Payload valid |
| `m_axis_tready` | Downstream backpressure |
| `m_axis_tlast` | End of UDP payload |

Only payload data is forwarded; all protocol headers are stripped.

---

## 5. Internal Architecture

The RX parser is implemented as a **single finite state machine (FSM)** that
advances once per AXI-Stream beat. Each FSM state corresponds to a specific
portion of the packet.

---

## 6. FSM States

| State | Description |
|------|-------------|
| `IDLE` | Wait for start of a new Ethernet frame |
| `ETH_BEAT1` | Capture Ethernet header fields |
| `ETH_BEAT2` | Validate EtherType and IP version |
| `IP_BEAT1` | Parse IPv4 protocol field |
| `IP_BEAT2` | Capture source and destination IP |
| `IP_BEAT3` | Parse UDP header |
| `UDP_BEAT` | Forward first payload beat |
| `PAYLOAD` | Stream remaining payload beats |
| `DROP` | Discard invalid packet |

---

## 7. Header Storage Registers

The following registers temporarily store parsed header fields:

- Destination MAC
- Source MAC
- EtherType
- IPv4 version and header length
- IPv4 total length
- IPv4 protocol
- Source IP
- Destination IP
- UDP source port
- UDP destination port
- UDP length
- Computed payload length

These registers allow protocol validation and future metadata extraction
without stalling the streaming datapath.

---

## 8. Protocol Validation

Validation is performed incrementally as headers are parsed:

### Ethernet Validation
- EtherType must equal `0x0800` (IPv4)

### IPv4 Validation
- Version field must indicate IPv4
- Header length assumed to be 20 bytes

### UDP Validation
- IPv4 protocol field must equal `17` (UDP)

If any validation fails, the FSM transitions to the `DROP` state.

---

## 9. State-by-State Operation

### 9.1 IDLE

- Asserts `s_axis_tready`
- Waits for the first beat of a new Ethernet frame
- Captures destination MAC and upper source MAC bits

---

### 9.2 ETH_BEAT1

- Completes source MAC extraction
- Captures EtherType
- Begins IPv4 parsing
- Validates EtherType

---

### 9.3 ETH_BEAT2

- Captures IPv4 total length
- Validates IPv4 version

---

### 9.4 IP_BEAT1

- Extracts IPv4 protocol field

---

### 9.5 IP_BEAT2

- Captures source and destination IP addresses
- Validates UDP protocol

---

### 9.6 IP_BEAT3

- Parses UDP header fields
- Computes payload length as `udp_length - 8`

---

### 9.7 UDP_BEAT

- First payload beat
- Input is accepted only if downstream is ready
- Ensures lossless payload forwarding

---

### 9.8 PAYLOAD

- Streams remaining payload beats transparently
- Backpressure propagates directly from output to input
- `tlast` terminates the packet

---

### 9.9 DROP

- Discards input data until `tlast`
- Suppresses output
- Ensures clean packet boundary recovery

---

## 10. Flow Control Strategy

- Header parsing always accepts data
- Payload streaming obeys downstream backpressure
- No internal buffering is used
- Deterministic, low-latency behavior

This makes the design suitable for high-throughput Ethernet MAC interfaces.
