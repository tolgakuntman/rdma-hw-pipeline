# Ethernet Header Builder (`eth_header`)

## Function

Constructs the 14-byte Ethernet header:

- Destination MAC
- Source MAC
- EtherType (IPv4)

## Operation

- Waits for successful endpoint lookup
- Emits one header per packet
- Holds header until downstream ready

## Output

112-bit header stream (padded/aligned for packer)
