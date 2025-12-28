# Overview

## Purpose

The IP Encapsulator is a hardware IP core that constructs complete
Ethernet/IPv4/UDP frames from a streaming payload and per-packet metadata.
It is intended for FPGA-based networking systems where packet assembly
must be done at line rate with full backpressure support.

---

## High-Level Function

For each packet:

1. Receive payload data via AXI-Stream
2. Receive packet metadata (IP addresses, ports, length)
3. Compute protocol lengths
4. Look up MAC addresses via BRAM
5. Generate Ethernet, IPv4, and UDP headers
6. Concatenate headers and payload
7. Emit a valid Ethernet frame

---

## Key Design Goals

- Fully streaming (no packet buffering)
- Backpressure-safe
- Modular header generation
- Software-configurable via AXI-Lite
- Deterministic latency per packet
