# Part 1 - Ethernet Subsystem Overview

Part 1 of the RDMA receiver architecture implements the complete Ethernet Layer-2 subsystem on the KR260 platform, including both the **transmit (TX)** and **receive (RX)** datapaths, RGMII PHY bring-up, MAC configuration, AXI-Stream buffering, and final integration with the RDMA decapsulation pipeline.  
This section documents every hardware and software building block required to achieve reliable 1 Gbps Ethernet operation using the **AXI 1G/2.5G Ethernet Subsystem (PG138)** and an RGMII PHY.

The goal is to provide a **fully deterministic, loss-free Ethernet front-end** that delivers raw Ethernet frames into the RDMA processing chain.

---

## 1. Scope of Part-1

Part-1 covers the following elements in full detail:

###  RGMII PHY Bring-Up
- MDIO access through the AXI Ethernet Subsystem
- BMCR/BMSR interpretation  
- Auto-negotiation flow  
- Link polling strategy  
- Reset sequencing and timing  
- 125 MHz clock requirements for RGMII regardless of link speed (10/100/1000 Mbps)

### AXI Ethernet Subsystem (MAC) Configuration
- TX/RX AXI-Stream interface behavior  
- Status channel decoding  
- FCS handling (strip/keep)  
- Flow control and pause frame behavior  
- MAC address configuration  
- Clocking mode (GTX clock vs recovered clock)  

### Full TX Pipeline (Stand-Alone Test Mode)
A dedicated AXI-Stream pattern generator transmits known Ethernet frames to validate:
- RGMII routing  
- MAC TX behavior  
- Clock timing relationship (TXC vs TXD)  
- Wireshark packet correctness  
- End-to-end electrical and timing integration  

This TX path was crucial for verifying physical connectivity and MAC/PHY configuration before integrating RDMA logic.

### Full RX Pipeline (Integrated With RDMA)
The RX pipeline implemented in Part-1 forms the front-end of the final RDMA receive architecture:
RGMII → Ethernet PHY → AXI Ethernet MAC (RX)→ s_axis_rxd + s_axis_rxs → axis_rx_to_rdma → RDMA decapsulation logic 


This path is responsible for:
- Loss-free AXI-Stream forwarding under backpressure  
- Correct `tlast`, `tkeep`, and status handling  
- Packet framing for RDMA header parser  
- Eliminating the timing hazards of AXI-Stream valid/ready behavior

The custom RX buffer (`axis_rx_to_bram`) was one of the most critical modules in the entire RDMA pipeline.

---

## 2. Motivation and Requirements

RDMA packets arrive as raw Ethernet frames. The higher RDMA layers (header parser, queue logic, DDR writer) require:

1. **Correctly delimited frames**
2. **Zero data loss**
3. **Correct packet boundaries (`tlast`)**
4. **Stable AXI-Stream behavior under backpressure**
5. **Low-latency delivery into header parser**
6. **Deterministic timing from RGMII → MAC → AXIS**

The Ethernet subsystem in Part-1 is responsible for guaranteeing all of these properties.

Even a single dropped or mis-aligned 32-bit word would break:
- RDMA header parsing  
- Queue number extraction  
- Payload alignment  
- Completion queue updates  

This is why our AXI-Stream buffering and MAC configuration are documented in extreme detail.

---

## 3. Development & Verification Stages (Chronological)

Part-1 was developed and tested in **three major configurations**, each validating a different subsystem:

### **Stage 1 — TX-Only Test (Wireshark Verification)**
- Ethernet TX path active  
- RX path disabled  
- Laptop/PC captures packets via Wireshark  
- Verified:
  - MAC timing
  - PHY negotiation
  - RGMII routing
  - MAC address correctness
  - Header fields and FCS behavior

This stage confirmed the hardware stack was electrically and logically correct.

---

### **Stage 2 — RX-Only Test (Python Packet Injection)**
- TX disabled  
- External PC injects Ethernet frames using Scapy  
- Received data stored into BRAM  
- Software reads BRAM to verify:
  - No dropped beats  
  - Correct ordering  
  - Correct `tlast` location  
  - Payload fidelity  
  - AXI-Stream `tvalid/tready` timing

This stage identified and resolved the **critical backpressure bug**:
- A one-deep buffer must hold data stable whenever `valid=1 && ready=0`

Without this fix, multicycle stalls in the RDMA validator caused random word loss.

---

### **Stage 3 — Final RDMA RX Integration**
The validated RX pipeline was connected to the complete RDMA decapsulation chain (from the provided PDF):
MAC RX → axis_rx_to_rdma  → RDMA Header Parser → RDMA Payload Writer → DDR via AXI DMA


This integration demonstrated:
- Full-speed RX at 1 Gbps
- Correct RDMA header extraction
- DDR writes matching transmitted payload
- Consistent operation with real RDMA packets

This is the final configuration used in the project.

---

## 4. Key Technical Insights (Directly Learned from Part-1)

These insights guide the later parts of the RDMA pipeline.

### **4.1 AXI-Stream Timing Is Not Optional — It Is EVERYTHING**
We learned through debugging that:
- `valid` must remain high  
- `data` and `keep` **must not change**  
- while `ready=0`

Otherwise:
- RDMA header parser receives corrupted words  
- Packets fragment  
- Partial payloads appear in DDR  

Our `axis_rx_to_bram` module enforces this rule strictly.

---

### **4.2 RGMII Always Uses 125 MHz (Even at 10/100 Mbps)**
The MAC *always* requires a 125 MHz clock, regardless of negotiated link speed.  
The PHY internally divides its clock to achieve 10/100 operation.

This was a critical clarification when interpreting PG138 and fixing clocking.

---

### **4.3 AXI Ethernet Status Channel Was Misunderstood Initially**
Correct meaning from PG138 (page 116):

- `tdata[15:0]`  → **frame length**
- `tdata[31:16]` → **VLAN/aux fields**
- `bit0`         → **frame_ok flag**

This correction prevented misalignment in RDMA payload length calculation.

---

### **4.4 The MAC Does Not Autodetect Speed — PHY Negotiates, MAC Obeys**
We learned:
- PHY negotiates speed with link partner  
- MAC speed must be explicitly configured  
- RGMII timing always expects 125 MHz refclk  
- PHY output clocking adapts internally  

This cleared up multiple misunderstandings about GMII vs RGMII.

---

## 5. Documentation Structure

Part-1 is documented across several detailed sections:

- **`timing_clocks.md`** – Clocking architecture  
- **`rgmii_phy.md`** – PHY electrical & logical behavior  
- **`tx_path.md`** – TX pipeline  
- **`rx_path.md`** – RX pipeline  
- **`rx_axis_to_rdma.md`** – Custom RX buffer module  
- **`axi_ethernet_subsystem.md`** – MAC configuration & internals  
- **`combined_bd.md`** – Final RDMA integration  
- **`vitis_sw_init.md`** – PHY bring-up software  

Each file focuses on a single subtopic.

---

## 6. Summary

Part-1 provides the entire foundational Ethernet subsystem required for the RDMA receiver.  
It handles:

- PHY configuration  
- MAC configuration  
- TX frame validation  
- RX frame forwarding  
- AXI-Stream correctness  
- Backpressure-safe buffering  
- Integration with the full RDMA pipeline  

Without this subsystem, the RDMA receiver cannot operate.

