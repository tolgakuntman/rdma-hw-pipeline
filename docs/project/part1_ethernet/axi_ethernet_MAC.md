# AXI 1G/2.5G Ethernet Subsystem — Full Port & Interface Documentation

This section explains every major interface of the AXI 1G/2.5G Ethernet Subsystem IP,
including the AXI4-Lite control path, AXI4-Stream TX/RX channels,
RGMII PHY interface, MDIO management, clock/reset structure, and how these are used
in the KR260 + DP83867 PHY design.

---

## 1. Overview
**Information about the Ethernet IP Block Used**
The AMD AXI Ethernet Subsystem implements a tri-mode (10/100/1000 Mb/s) Ethernet MAC
or a 10/100 Mb/s Ethernet MAC. This core supports the use of MII, GMII, SGMII, RGMII, and
1000BASE-X interfaces to connect a media access control (MAC) to a physical-side interface
(PHY) chip. It also provides an on-chip PHY for 1G/2.5G SGMII and 1000/2500 BASE-X modes.
The MDIO interface is used to access PHY Management registers. This subsystem optionally
enables TCP/UDP full checksum offload, VLAN stripping, tagging, translation, and extended
filtering for multicast frames features.


This subsystem provides additional functionality and ease of use related to Ethernet. Based on
the configuration, this subsystem creates interface ports, instantiates required infrastructure cores, and connects these cores.

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
Here is a picture of this MAC ip used in the final RDMA design.

![ethernet](images/MAC_ip.png)

---
## 2. VERY IMPORTANT INFORMATIONS BEFORE STARTING WITH THE MAC
### 2.1 LICENSE INFORMATION ABOUT THIS IP BLOCK
Note that an evaluation license (Hardware Evaluation) for Tri-Mode Ethernet MAC IP has been obtained. It will not compile without it.

![error](images/license_error.png)

From the following link, it is possible to get 4 month free trial license for this ip.

[License Link](https://login.amd.com/app/amd_accountamdcom_1/exk559qg7f4aW4yim697/sso/saml?SAMLRequest=fVLLbsIwEPyVyHdwEhECFkGioKpItEVAW6kX5JgNWHXs4HVa%2BPuaQF%2BHcvJqPTuznvEAeakqNqrdTi9gXwO64FAqjay5yEhtNTMcJTLNS0DmBFuO7mcsboesssYZYRQJRohgnTR6bDTWJdgl2Hcp4Gkxy8jOuQoZpVwIU2vX5uWmLUxJTwoUK%2BppCqmAVgadByEJJn4NqfmJ8Gdcma3U38O8qqiv1xdSX%2FruOqJweEuS%2Fn6bFh3%2B0jnKsttPKaJp1EgwnWRk3Sl6ScRTHnbTYtMNedELU9hESd6BKM9FHIl%2BnsQejFjDVKPj2mUkDuOkFcWtOFlFfZb0WJi2wzB%2BJcGtsQIaCzNScIVAgvnFmhupN1Jvr%2FuYn0HI7lareWv%2BuFyR4BksNs%2F3ADIcnLZnzT72Vz7XaflXKGT4XwT%2BvLQG9JfEWa9iD55zOpkbJcUxGCllPsYWuIOMOFsDocPz1N%2F%2FM%2FwE&RelayState=https%3A%2F%2Faccount%2Eamd%2Ecom%2Fen%2Fforms%2Flicense%2Flicense%2Dform%2Ehtml)

Choose this option and the ethernet ip block will be functional.
![license](images/license.png)

You can follow this link for the detailed explanation. 
[License Link](https://digilent.com/reference/vivado/temac?srsltid=AfmBOopFCrHFR-mmgt0yZ6U_JD0973M5YUpqqRmJV5cOFaeGCqq5kVro)

### 2.2 Creating VIVADO Projects with Kria - Manage Board Connection for PL ETHERNET

While creating VIVADO project for Kria Boards, there is "Connections --> Manage Board Connections" option. This option is really helpful for designing projects for Kria Boards which include popular interfaces as GPIO, MIPI, I2C on KV260 and PL Ethernet, SFP connection, Pmod, Clocks on KR260. After proper selection of "Manage Board Connection" option we can get some of the most used interface connections easily and it also pulls the Constraint itself.

#### KR260 VIVADO project creation with Board Connections
1. Here we can select Connector for KR260- SoM240_1 and SoM240_2, here is an example:
![connection1](images/connection1.png)
2. Now on creating Block Design, we can again see multiple Interfaces available on KR260 Board Connector, example we can get SFP connector , PL Ethernet , Pmod etc.
![connection2](images/connection2.png)

As an example, i have added two PL Ethernet (GEM2 and GEM3 RGMII Ethernet) on above Kria KR260 Board based Block Design. You can drag from the board screen and place the PL GEM2 RGMII ETHERNET ip with external connections in your block design. VIVADO automatically configure the PL Ethernet IP(AXI 1G/2.5G Ethernet Subsystem IP) and pulls the constraint for it from Board file. 

When selecting them via Board Connections:
- Vivado automatically instantiates AXI 1G/2.5G Ethernet Subsystem (the MAC)
- It automatically wires RGMII signals
- It automatically imports the correct constraints like pin locations, I/O standards, RGMII timing requirements
- It automatically wires MDIO signals
- It automatically wires PHY reset signal

I used GEM2 PL ethernet port for the project. Here is an image for the 4 ethernet ports that are present on the kr260 board.
![ports](images/ethernet_ports.png)


### 2.3 Checking the Settings of the PL Ethernet Subsystem in Vivado 
The most important steps to do before being able to work with this ip block in our RDMA project were getting the license and setting board-based I/O constraints before starting the project. So after doing these two steps we can finally customize the block specifically for our board kria kr260. We can see the board based IO constraints that we previously generated on the first page.

![ethernet_board](images/ethernet_board.png)

In the physical interface part we can see RGMII and 1gbps speed is preselected. The reason we cannot have any other option is because on the KR260, the GEM2 PL Ethernet port is hard-wired for RGMII. No other MAC–PHY physical interface (GMII, SGMII, MII, RMII) is supported on this port.

![ethernet_board](images/phy_screen.png)

The information for all ports is also written in Kria KR260 Robotics Starter Kit User Guide (UG1092).

![ethernet_board](images/eth_ports.png)

## 3. AXI-Stream TX Path (Custom IP → MAC)

This part will be a quick summary to include all pin explanations in this section. These two tx channels will be explained in detail in the rxtx_to_rdma custom ip block.

TX requires **two separate AXI4-Stream channels**:

1. **TX Control** (`s_axis_txc`)  
2. **TX Data** (`s_axis_txd`)  

The MAC enforces a strict ordering rule:

> **TXC must finish completely before TXD is allowed.  
> If not, the MAC drops the entire frame.**

---

### 3.1 `s_axis_txc` — TX Control Stream

Exactly **6 words** per Ethernet frame (Normal Transmit Mode).

| Signal | Description |
|--------|-------------|
| `tdata[31:0]` | Control word |
| `tkeep[3:0]` | Byte mask (always `0xF`) |
| `tvalid` | Control word valid |
| `tready` | MAC ready |
| `tlast` | Asserted on word 5 (6th txc word) |

#### TXC Word Format (from PG138 ethernet block datasheet)

| Word | Purpose |
|------|---------|
| Word 0 | Flag = `0xA` (Normal Transmit) |
| Words 1–5 | Reserved, set to `0x00000000` |

We always use:
`0xA0000000`


This selects **Normal Transmit AXI4-Stream Frame**, not “Receive-Status Transmit”.

---

### 3.2 `s_axis_txd` — TX Data Stream

Actual Ethernet bytes are streamed here.

| Signal | Description |
|--------|-------------|
| `tdata[31:0]` | 32-bit payload word |
| `tkeep[3:0]` | Last-word mask |
| `tvalid` | Payload valid |
| `tready` | Backpressure from MAC |
| `tlast` | End of frame |

#### Requirements

- Data beats must be **continuous** until `tlast=1`
- `tkeep` accurate on the last word
- No gaps while `tvalid=1`

---

### 3.3 Full TX Timing (AXI4-Stream Transmit Control → AXI4-Stream Transmit Data)

TXC Stage:
Word0 Word1 Word2 Word3 Word4 Word5 (tlast=1) [tready=1] → MAC accepts full TXC frame

TXD Stage:
Data0 Data1 ... DataN (tlast=1) [tready=1] → MAC transmits via RGMII

If TXC does not finish cleanly:  
**MAC will not raise `s_axis_txd_tready` → TXD is blocked forever.**

---

## 4. AXI-Stream RX Path (MAC → Custom IP)

MAC sends **two streams** back-to-back:

1. Full Ethernet payload (`m_axis_rxd`)
2. A 6-word RX status frame (`m_axis_rxs`)

---

### 4.1 `m_axis_rxd` — RX Data Stream

| Signal | Meaning |
|--------|---------|
| `tdata[31:0]` | Ethernet/IP/RDMA bytes |
| `tkeep[3:0]` | Last-word mask |
| `tvalid` | Data valid |
| `tlast` | End of frame |
| `tready` | Backpressure from RDMA RX |

MAC guarantees each packet arrives as **one contiguous AXI burst**.

---

### 4.2 `m_axis_rxs` — RX Status Stream

Each RX packet is followed by **6 words** of status information.

#### Word 5, bits[15:0]:


Other words contain:

- Frame OK  
- VLAN info  
- Checksum flags  
- MAC filtering results  
- Optional offload information  

Our custom RDMA RX uses only the **length field**, which I did not implement in the final design.

---

## 5. Reset Signals

| Port | Purpose |
|------|----------|
| `axi_txc_aresetn` | Reset for TXC |
| `axi_txd_aresetn` | Reset for TXD |
| `axi_rxd_aresetn` | Reset for RXD |
| `axi_rxs_aresetn` | Reset for RXS |

All of these reset pins are connected to Processor System Reset block which is connected to the clock coming from PS `pl_clk0` from slowest_sync_clk pin. Like all other ip blocks in the block design, all four reset pins of the MAC are connected to this `peripheral_aresetn` pin of the reset block. So as a summary, since all ip blocks are driven by PS clock I connected them to the same clock domain reset.

Also as a sidenote, `ext_reset_in` pin of that reset block is connected to `pl_resetn0` pin of PS.

![error](images/reset_ip.png)

---

## 6. Clocks

Clocks are another important part of this ethernet ip block. From the PG138 datasheet we can have a detailed information about clock pins and how to set them. 

The axis_clk signal should be connected to the same clock source as the AXI4-Stream
interface.




KR260 Part-1 clock structure:

| Clock | Description |
|--------|-------------|
| `axis_clk` | 100 MHz clock for all AXI-Stream TX/RX paths |
| `ref_clk` | 125 MHz reference (required for RGMII transmit clock) |
| `gtx_clk` | GMII-only — unused in RGMII mode |

---

## 7. RGMII PHY Interface (DP83867)

### 7.1 RX (PHY → MAC)

| Port | Description |
|------|-------------|
| `rgmii_rxd[3:0]` | Incoming nibble |
| `rgmii_rx_ctl` | RX_DV + RX_ER |
| `rgmii_rx_clk` | PHY-generated RX clock |

### 7.2 TX (MAC → PHY)

| Port | Description |
|------|-------------|
| `rgmii_txd[3:0]` | Outgoing nibble |
| `rgmii_tx_ctl` | TX_EN + TX_ER |
| `rgmii_tx_clk` | MAC-generated TX clock (125 MHz) |

DP83867 is strapped in **RGMII-ID Mode (internal TX clock delay)**.

---

## 8. MDIO/MDC Management

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

## 9. Interrupt

| Port | Description |
|------|-------------|
| `mac_irq` | TX complete, RX complete, errors |

Unused in this project.

---

## 10. PHY Reset

| Port | Description |
|------|-------------|
| `phy_rst_n[0]` | Reset output to DP83867 |

---

## 12. Summary



# AXI Ethernet Subsystem — Full Port & Interface Documentation  
*Complete Markdown Version (for KR260 RDMA Project)*

This document provides a clean, structured explanation of all external ports of the  
**AXI 1G/2.5G Ethernet Subsystem**, based on **PG138 v7.2**, KR260 schematics, and real Vivado behavior.

It covers:

- AXI4-Lite control interface  
- AXI4-Stream TX & RX interfaces  
- GMII / RGMII / MII / SGMII / SFP external MAC–PHY interfaces  
- MDIO management  
- Required clocks (ref_clk, gtx_clk)  
- PHY reset signal  
- All interrupts (mac_irq, interrupt)  
- Full port tables rewritten in Markdown  
- KR260 GEM2 → DP83867 RGMII explanation

---

# 1. Overview

The AXI 1G/2.5G Ethernet Subsystem provides three major functional layers:

1. **AXI4-Lite** — software configuration  
2. **AXI4-Stream** — transmit and receive data streams  
3. **GMII / RGMII / SGMII** — external Ethernet MAC–PHY physical interface  

On the **KR260**, the board wiring is:
MPSoC GEM2 MAC → AXI Ethernet Subsystem → RGMII → DP83867 PHY → RJ45


This path is **fixed in hardware**.

---

# 2. I/O Interfaces (Markdown Rewrite of Table 5)

## 2.1 AXI4-Lite Control Interface — `s_axi`

| Signal Name        | Direction | Description |
|--------------------|-----------|-------------|
| `s_axi_lite_clk`   | In        | AXI4-Lite clock input |
| `s_axi_lite_resetn`| In        | Active-low reset |
| `s_axi_awaddr[31:0]` | In     | Write address |
| `s_axi_awvalid`    | In        | Write address valid |
| `s_axi_awready`    | Out       | Write address ready |
| `s_axi_wdata[31:0]`| In        | Write data |
| `s_axi_wstrb[3:0]` | In        | Byte enables |
| `s_axi_wvalid`     | In        | Write valid |
| `s_axi_wready`     | Out       | Write ready |

---

# 3. AXI-Stream Interfaces

## 3.1 Transmit Control — `s_axis_txc`

| Signal | Direction | Description |
|--------|-----------|-------------|
| `axis_clk` | In | AXI-Stream clock (TX, RX, Status all use same clock) |
| `axi_str_txc_aresetn` | In | Reset |
| `axi_str_txc_tvalid` | In | Control frame valid |
| `axi_str_txc_tready` | Out | Control frame ready |
| `axi_str_txc_tlast`  | In | Last control word |

**MAC requires exactly 6 control words**.  
`Word0.flag = 0xA` (Normal Transmit Frame).  
Words 1–5 = zero.

---

## 3.2 Transmit Data — `s_axis_txd`

| Signal | Direction | Description |
|--------|-----------|-------------|
| `axi_str_txd_tvalid` | In | TX data beat valid |
| `axi_str_txd_tready` | Out | MAC ready |
| `axi_str_txd_tlast`  | In | End of frame |

TXD follows TXC:
TXC (6 words) → MAC asserts tready → TXD begins

This order **must never** be violated.

---

## 3.3 Receive Data — `m_axis_rxd`

| Signal | Direction | Description |
|--------|-----------|-------------|
| `m_axis_rxd_tdata[31:0]` | Out | RX data beat |
| `m_axis_rxd_tkeep[3:0]` | Out | Byte enables |
| `m_axis_rxd_tvalid` | Out | Data valid |
| `m_axis_rxd_tready` | In | Backpressure from user logic |
| `m_axis_rxd_tlast` | Out | End of frame |

RX produces **a continuous burst** from first byte to last byte.

---

## 3.4 Receive Status — `m_axis_rxs`

| Signal | Dir | Description |
|--------|-----|-------------|
| `m_axis_rxs_tdata` | Out | Status frame (6 words) |
| `m_axis_rxs_tvalid`| Out | Status valid |
| `m_axis_rxs_tready`| In  | User ready |
| `m_axis_rxs_tlast` | Out | End of status frame |

Status word 5 lower 16 bits = **frame length in bytes**.

---

# 4. External MAC–PHY Interfaces

## 4.1 MDIO — `mdio`

| Interface | Description |
|-----------|-------------|
| `mdio_mdc` | Clock to PHY |
| `mdio_mdio_i` | Management input |
| `mdio_mdio_o` | Management output |
| `mdio_mdio_t` | Tristate control |

This is always present for **MII, GMII, RGMII, SGMII** modes.

---

## 4.2 MII — `mii`

Available **only** in MII mode.  
Not used on KR260.

---

## 4.3 GMII — `gmii`

Available **only** in GMII mode.  
KR260 **does not use GMII** — wiring is RGMII only.

---

## 4.4 RGMII — `rgmii`

| Interface | Description |
|----------|-------------|
| `rgmii_txd[3:0]` | Data to PHY |
| `rgmii_tx_ctl`   | TX control |
| `rgmii_txc`      | 125MHz DDR clock |
| `rgmii_rxd[3:0]` | Data from PHY |
| `rgmii_rx_ctl`   | RX control |
| `rgmii_rxc`      | DDR clock from PHY |

**KR260 uses RGMII only.**  
RGMII is the physical wiring between:
AXI Ethernet Subsystem → DP83867 PHY → RJ45


No other PHY interface exists on GEM2.

---

## 4.5 SGMII — `sgmii`

Only available if the subsystem is configured in SGMII mode.  
KR260 PL Ethernet *does not route SGMII pins* for GEM2.

(Not used.)

---

## 4.6 SFP — `sfp`

Used only in **1000BASE-X / SGMII** subsystem mode,  
connects to an optical SFP cage.

KR260 GEM2 does **not** use this.

---

# 5. Required Clocks

## 5.1 `ref_clk`

Stable global clock for PHY transceiver logic.  
Used primarily in SGMII / 1000BASE-X modes.

KR260 RGMII mode **does not require connecting an external ref_clk**.

---

## 5.2 `gtx_clk`

The most important clock for RGMII/GMII mode:

- 125MHz
- Drives transmit timing
- Used for statistics counters
- Required by DP83867 PHY

KR260 routes a 125MHz clock correctly from the Clocking Wizard.

---

# 6. System Ports

## 6.1 Interrupts

| Signal | Description |
|--------|-------------|
| `interrupt` | Global subsystem interrupt |
| `mac_irq`  | TEMAC interrupt (primarily MDIO events) |

---

# 7. PHY Reset

| Signal | Direction | Description |
|--------|-----------|-------------|
| `phy_rst_n` | Out | Active-low PHY reset (held low 10ms after power-up, +5ms idle) |

KR260 board design automatically ties this to the DP83867 reset pin.

---

# 8. KR260 GEM2 Ethernet — Physical Mode Limitation

### **Short Answer (for your documentation):**




