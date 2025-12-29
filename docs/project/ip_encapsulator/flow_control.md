# Flow Control Strategy

## Backpressure Handling

- All modules use valid/ready handshakes
- Payload backpressure propagates upstream
- Metadata readiness depends on all consumers

## Meta Ready Logic

Metadata is only accepted when:

- Length calculator ready
- Endpoint lookup ready
- IPv4 header builder ready
- UDP header builder ready

This ensures consistent per-packet state.
