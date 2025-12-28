# Header Packer (`header_packer`)

## Purpose

Combines all headers and payload into a single AXI-Stream frame.

## Inputs

- Ethernet header
- IPv4 header
- UDP header
- Payload stream

## Operation

State machine:

1. Wait for all headers
2. Stream headers (aligned to data width)
3. Stream payload
4. Assert `tlast` on final payload beat

## Responsibilities

- Header alignment
- `tkeep` generation
- Correct packet boundary handling
