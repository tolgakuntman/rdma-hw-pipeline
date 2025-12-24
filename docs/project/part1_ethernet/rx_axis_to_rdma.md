# AXIS RX_to_RDMA Block

The RDMA RX Block is the final stage of the receive path. It converts raw AXI-Stream Ethernet frames coming from the MAC into structured RDMA packets that the rest of the system can consume. This block is identical in Part-1 standalone, Part-3 integrated RDMA, and all future versions — the logic never changes.

---

## 1. Role in the System

End-to-end pipeline (final design):

```
PHY (DP83867)
     ↓ RGMII
AXI Ethernet Subsystem (MAC)
     ↓ m_axis_rxd (data)
     ↓ m_axis_rxs (status)
AXIS_RX_TO_RDMA  ←––––––– this block
     ↓ structured RDMA packet
Decapsulator
```

The RDMA RX block is a pass through block that takes the frames from MAC and passes the packets to decapsulator. For tx side, this block triggers txc (tx control line) in a certain way to start sending packets to the MAC, again it passes packets from encapsulator through the MAC.

---

## 2. Inputs From MAC

The AXI Ethernet Subsystem outputs two streams.

---

### 2.1 `m_axis_rxd` — RX Data Stream

| Signal        | Meaning                                  |
|--------------|-------------------------------------------|
| `tdata[31:0]` | Ethernet/IP/UDP/RDMA payload bytes        |
| `tkeep[3:0]`  | Byte enables (last word alignment)        |
| `tvalid`      | Data valid indicator                     |
| `tlast`       | End of frame                             |
| `tready`      | Asserted by our block (backpressure)     |

The MAC guarantees each Ethernet frame arrives as **one continuous AXI-Stream burst**.

---

### 2.2 `m_axis_rxs` — RX Status Stream

A single 32-bit word per frame containing:

- Length in bytes  
- Frame OK flag  
- Optional VLAN / checksum flags  

We latch this after the frame ends.

> **NOTE (screenshot):** Insert PG138 “RX Status Word Format” figure.

---

## 3. Stage B — Header Parsing  
*(Ethernet → IP → UDP → RDMA)*

After a full frame is buffered, parsing begins.

---

### 3.1 Ethernet Header

We extract:

- Destination MAC  
- Source MAC  
- EtherType (must be IPv4)

If:
```
EtherType ≠ 0x0800
```
→ frame is discarded.

---

### 3.2 IPv4 Header

We check:

- Version & IHL  
- Total Length  
- Protocol must be UDP  
- Destination IP must match KR260 endpoint  

If any mismatch occurs:
→ frame dropped.

---

### 3.3 UDP Header

We validate:

- Source Port  
- Destination Port (must match RDMA service port)  
- Length field  
- Optional checksum handling  

---

### 3.4 RDMA Header (Custom Protocol)

Our custom RDMA header includes:

- Opcode  
- Queue Pair Number (QPN)  
- Offset / Address  
- Payload Length  
- Optional flags  

These become **RDMA packet metadata** delivered to the RDMA Core.

> **NOTE (diagram):** Insert header breakdown:
> `[ETH][IP][UDP][RDMA][Payload]`

---

## 4. Stage C — Delivering RDMA Payload

Once RDMA header is validated:

- RDMA payload begins immediately after the header  
- RDMA RX block streams payload to RDMA Core  
- RDMA Core decides storage / write target  

If:

- Header invalid  
- OR status word indicates error (`frame_ok = 0`)

Then:
→ **Entire frame discarded** before payload delivery.

---

## 5. Why This Block Is Identical in All Versions

This block:

- Does **NOT** depend on TX test generators  
- Does **NOT** depend on BRAM buffering configuration  
- Does **NOT** depend on PHY / MDIO / negotiation  
- Does **NOT** depend on encapsulator or TX RDMA logic  

It only requires:

1. `m_axis_rxd` (AXI-Stream data)
2. `m_axis_rxs` (AXI-Stream status)

Since these are identical across:

- Standalone Part-1  
- RDMA Part-3  
- Final integrated design  

→ **The same RDMA RX block is fully reusable.**

---

## 6. Summary

The AXIS RX → RDMA Block performs:

- Lossless capture of MAC RX frames  
- Parsing of Ethernet / IPv4 / UDP headers  
- Extraction of RDMA metadata  
- Delivery of validated RDMA payload  
- Full abstraction from networking layers  

This makes the RDMA system modular:

```
PHY + MAC  →  AXIS RX → RDMA  →  RDMA Core
```

MAC + PHY handle Ethernet.  
RDMA RX handles transport framing.  
RDMA Core handles semantics and placement.

---
