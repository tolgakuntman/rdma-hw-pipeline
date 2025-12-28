# Endpoint Lookup (`endpoint_lookup`)

## Purpose

Maps a destination IP address to:

- Destination MAC address
- Source MAC address

## Storage

Uses external BRAM with entries containing:

- Valid bit
- Stored destination IP
- Destination MAC
- Source MAC

## Lookup Flow

1. Hash destination IP to BRAM address
2. Read BRAM entry
3. Check valid bit
4. Compare stored IP
5. Output MAC addresses or error

## Error Handling

- Miss or collision raises `lookup_error`
- Error is latched for software visibility
