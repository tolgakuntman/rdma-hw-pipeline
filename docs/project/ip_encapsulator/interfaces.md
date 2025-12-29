# Interfaces

## AXI-Stream Payload Input (`s_axis_*`)

Carries the packet payload data.

Signals:

- `tdata`: Payload data
- `tkeep`: Byte-valid mask
- `tvalid`: Data valid
- `tready`: Backpressure from IP
- `tlast`: End of packet

Payload data is not modified by the encapsulator.

---

## Metadata Interface (`meta_*`)

One metadata beat per packet.

Metadata fields include:

- Payload length
- Source IP
- Destination IP
- Source port
- Destination port
- Flags
- Endpoint ID

Metadata is consumed once and aligned with the first payload beat.

---

## AXI-Stream Output (`m_axis_*`)

Outputs complete Ethernet frames including headers and payload.

- Headers appear first
- Payload follows
- `tlast` marks end of Ethernet frame

---

## BRAM Interface

Used for endpoint lookup:

- Address generation
- Synchronous read
- External Block Memory Generator

---

## AXI-Lite Interface

Used for:

- Control
- Status reporting
- Statistics
- Error flags
