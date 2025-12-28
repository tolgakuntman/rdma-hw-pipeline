# Length Calculation (`length_calc`)

## Purpose

Computes protocol length fields required for IPv4 and UDP headers.

## Inputs

- Payload length (bytes)
- Valid/ready handshake

## Outputs

- UDP length = payload length + 8
- IP total length = UDP length + 20

## Design Notes

- Stateless per packet
- Output held valid until accepted
- Guarantees consistent length usage across headers and counters
