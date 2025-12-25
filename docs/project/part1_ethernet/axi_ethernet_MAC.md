# AXI 1G/2.5G Ethernet Subsystem — Full Port & Interface Documentation

This section explains every major interface of the AXI 1G/2.5G Ethernet Subsystem IP,
including the AXI4-Lite control path, AXI4-Stream TX/RX channels,
RGMII PHY interface, MDIO management, clock/reset structure, and how these are used
in the KR260 + DP83867 PHY design.

---

# 1. Overview

The AXI Ethernet Subsystem is logically divided into three layers:

1. **AXI4-Lite Control Interface**  
2. **AXI4-Stream TX/RX Data Interfaces**  
3. **RGMII Physical Ethernet Interface**

System position:

```
DP83867 PHY
     ↓ RGMII
AXI Ethernet Subsystem (MAC) ←––––––– this block
     ↓ m_axis_rxd (data)
     ↓ m_axis_rxs (status)
AXIS_RX_TO_RDMA (Custom IP)
```

---

# 2. AXI4-Lite Interface (MAC Register Access)

### Ports

| Port | Description |
|------|-------------|
| `s_axi_aw*` | AXI write address |
| `s_axi_w*`  | AXI write data |
| `s_axi_b*`  | Write response |
| `s_axi_ar*` | AXI read address |
| `s_axi_r*`  | Read data/response |
| `s_axi_lite_clk` | AXI-Lite clock |
| `s_axi_lite_resetn` | AXI-Lite reset |

### Used to Configure

- MAC address  
- Enable TX/RX datapaths  
- Flow control enable  
- FCS stripping  
- MDIO access to DP83867 PHY  
- Operating speed  
- Starting / stopping MAC  

---

# 3. AXI-Stream TX Path (Custom IP → MAC)

TX requires **two separate AXI4-Stream channels**:

1. **TX Control** (`s_axis_txc`)  
2. **TX Data** (`s_axis_txd`)  

The MAC enforces a strict ordering rule:

> **TXC must finish completely before TXD is allowed.  
> If not, the MAC drops the entire frame.**

---

## 3.1 `s_axis_txc` — TX Control Stream

Exactly **6 words** per Ethernet frame (Normal Transmit Mode).

| Signal | Description |
|--------|-------------|
| `tdata[31:0]` | Control word |
| `tkeep[3:0]` | Byte mask (always `0xF`) |
| `tvalid` | Control word valid |
| `tready` | MAC ready |
| `tlast` | Asserted on word 5 |

### TXC Word Format (PG138 Table 2-27)

| Word | Purpose |
|------|---------|
| Word 0 | Flag = `0xA` (Normal Transmit) |
| Words 1–5 | Reserved, set to `0x00000000` |

We always use:
`0xA0000000`


This selects **Normal Transmit AXI4-Stream Frame**, not “Receive-Status Transmit”.

---

## 3.2 `s_axis_txd` — TX Data Stream

Actual Ethernet bytes are streamed here.

| Signal | Description |
|--------|-------------|
| `tdata[31:0]` | 32-bit payload word |
| `tkeep[3:0]` | Last-word mask |
| `tvalid` | Payload valid |
| `tready` | Backpressure from MAC |
| `tlast` | End of frame |

### Requirements

- Data beats must be **continuous** until `tlast=1`
- `tkeep` accurate on the last word
- No gaps while `tvalid=1`
- Correct little-endian byte packing:
  
tdata[7:0] = byte0
tdata[15:8] = byte1
tdata[23:16] = byte2
tdata[31:24] = byte3

---

## 3.3 Full TX Timing (Control → Data)

TXC Stage:
Word0 Word1 Word2 Word3 Word4 Word5 (tlast=1)
↓ ↓ ↓ ↓ ↓ ↓
[tready=1] → MAC accepts full TXC frame

TXD Stage:
Data0 Data1 ... DataN (tlast=1)
↓ ↓ ↓
[tready=1] → MAC transmits via RGMII


If TXC does not finish cleanly:  
**MAC will not raise `s_axis_txd_tready` → TXD is blocked forever.**

---

# 4. AXI-Stream RX Path (MAC → Custom IP)

MAC sends **two streams** back-to-back:

1. Full Ethernet payload (`m_axis_rxd`)
2. A 6-word RX status frame (`m_axis_rxs`)

---

## 4.1 `m_axis_rxd` — RX Data Stream

| Signal | Meaning |
|--------|---------|
| `tdata[31:0]` | Ethernet/IP/UDP/RDMA bytes |
| `tkeep[3:0]` | Last-word mask |
| `tvalid` | Data valid |
| `tlast` | End of frame |
| `tready` | Backpressure from RDMA RX |

MAC guarantees each packet arrives as **one contiguous AXI burst**.

---

## 4.2 `m_axis_rxs` — RX Status Stream

Each RX packet is followed by **6 words** of status information.

### Word 5, bits[15:0]:


Other words contain:

- Frame OK  
- VLAN info  
- Checksum flags  
- MAC filtering results  
- Optional offload information  

Your custom RDMA RX uses only **length**, which is correct.

---

# 5. Reset Signals

| Port | Purpose |
|------|----------|
| `axi_txc_aresetn` | Reset for TXC |
| `axi_txd_aresetn` | Reset for TXD |
| `axi_rxd_aresetn` | Reset for RXD |
| `axi_rxs_aresetn` | Reset for RXS |

---

# 6. Clocks

KR260 Part-1 clock structure:

| Clock | Description |
|--------|-------------|
| `axis_clk` | 100 MHz clock for all AXI-Stream TX/RX paths |
| `ref_clk` | 125 MHz reference (required for RGMII transmit clock) |
| `gtx_clk` | GMII-only — unused in RGMII mode |

---

# 7. RGMII PHY Interface (DP83867)

## 7.1 RX (PHY → MAC)

| Port | Description |
|------|-------------|
| `rgmii_rxd[3:0]` | Incoming nibble |
| `rgmii_rx_ctl` | RX_DV + RX_ER |
| `rgmii_rx_clk` | PHY-generated RX clock |

## 7.2 TX (MAC → PHY)

| Port | Description |
|------|-------------|
| `rgmii_txd[3:0]` | Outgoing nibble |
| `rgmii_tx_ctl` | TX_EN + TX_ER |
| `rgmii_tx_clk` | MAC-generated TX clock (125 MHz) |

DP83867 is strapped in **RGMII-ID Mode (internal TX clock delay)**.

---

# 8. MDIO/MDC Management

| Port | Description |
|------|-------------|
| `mdio_mdc` | MDIO clock |
| `mdio_mdio_i` | PHY → MAC |
| `mdio_mdio_o` | MAC → PHY |
| `mdio_mdio_t` | Tristate control |

Used for:

- Reading PHY link status  
- Auto-negotiation control  
- Speed/duplex configuration  
- Reading BMSR/BMCR registers  

---

# 9. Interrupt

| Port | Description |
|------|-------------|
| `mac_irq` | TX complete, RX complete, errors |

Unused in this project.

---

# 10. PHY Reset

| Port | Description |
|------|-------------|
| `phy_rst_n[0]` | Reset output to DP83867 |

---

# 11. GMII/MII Ports

These are unused because KR260 operates in **RGMII mode only**.

---

# 12. Summary

The AXI Ethernet Subsystem bridges:

AXI-Lite → MAC configuration
AXI-Stream → TX/RX datapaths
RGMII → Physical link to DP83867