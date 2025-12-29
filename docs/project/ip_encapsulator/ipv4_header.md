# IPv4 Header Builder (`ipv4_header_builder`)

## Function

Generates a standard 20-byte IPv4 header.

## Fields Generated

- Version & IHL
- Total length
- Identification
- TTL
- Protocol (UDP)
- Source IP
- Destination IP
- Header checksum

## Checksum

Computed internally based on header fields.

## Design Notes

- One header per packet
- Stateless except identification counter
- Backpressure-safe
