# UDP Header Builder (`udp_header`)

## Function

Generates an 8-byte UDP header.

## Fields

- Source port
- Destination port
- Length
- Checksum (set to zero)

## Notes

- UDP checksum omitted for simplicity
- Length derived from `length_calc`
