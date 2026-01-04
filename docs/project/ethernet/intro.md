# Ethernet Subsystem Overview

Ethernet part of the RDMA architecture implements the complete Ethernet Layer-2 subsystem on the KR260 platform, including both the **transmit (TX)** and **receive (RX)** datapaths, RGMII PHY bring-up, MAC configuration, AXI-Stream buffering, and final integration with the RDMA decapsulation pipeline.  
This section documents every hardware and software building block required to achieve reliable 1 Gbps Ethernet operation using the **AXI 1G/2.5G Ethernet Subsystem (PG138)** and an RGMII PHY on the KR260 platform.

The goal is to provide a **fully deterministic, loss-free Ethernet front-end** that delivers Ethernet frames into the RDMA processing chain.

---

## 1. Scope of Ethernet Subsystem

The following elements are covered in full detail:

###  RGMII PHY Bring-Up

- MDIO access through the AXI Ethernet Subsystem
- BMCR/BMSR interpretation  
- Auto-negotiation flow  
- Link polling strategy  
- Reset sequencing and timing  
- 125 MHz input clock requirements for RGMII regardless of link speed (10/100/1000 Mbps)

### AXI Ethernet Subsystem (MAC) Configuration

- TX/RX AXI-Stream interface behavior  
- MAC address configuration  
- Clocking mode (GTX clock) 

### Full TX Pipeline (Separate Tx test)
A dedicated AXI-Stream pattern generator transmits known Ethernet frames to validate:

- RGMII routing  
- MAC TX behavior   
- Wireshark packet correctness  

This TX path was crucial for verifying physical connectivity and MAC/PHY configuration before integrating RDMA logic.

### Full RX Pipeline (Integrated With RDMA)

The RX pipeline implemented in ethernet part forms the front-end of the final RDMA receive architecture:
Ethernet PHY → RGMII →AXI Ethernet MAC (RX)→ s_axis_rxd + s_axis_rxs → axis_rx_to_rdma → RDMA decapsulation logic 

This path is responsible for:

- Loss-free AXI-Stream forwarding under backpressure  
- Correct `tlast`, `tkeep`, and status handling  
- Eliminating the timing hazards of AXI-Stream valid/ready behavior

The custom RX pass through ip block (`axis_rx_to_rdma`) was one of the most critical modules in the entire RDMA pipeline.

---

## 2. Requirements

RDMA packets arrive as raw Ethernet frames. The higher RDMA layers (header parser, queue logic, DDR writer) require:

1. **Zero data loss**
2. **Correct packet boundaries (`tlast`)**
3. **Stable AXI-Stream behavior under backpressure**
4. **Low-latency delivery into header parser**
5. **Deterministic timing from RGMII → MAC → AXIS**

The Ethernet subsystem is responsible for guaranteeing all of these properties.

Even a single dropped or mis-aligned 32-bit word would break:

- RDMA header parsing  
- Queue number extraction  
- Payload alignment  
- Completion queue updates  

---

## 3. Development & Verification Stages (Chronological)

Part-1 was developed and tested in **three major configurations**, each validating a different subsystem:

### **Stage 1 — TX-Only Test (Wireshark Verification)**

- Ethernet TX path active  
- RX path disabled  
- Laptop/PC captures packets via Wireshark  

Verified:

  - MAC timing
  - PHY negotiation
  - RGMII routing
  - MAC address correctness

This stage confirmed the hardware stack was electrically and logically correct.

---

### **Stage 2 — RX-Only Test (Python Packet Injection)**

- TX disabled  
- External PC injects Ethernet frames using Scapy  
- Received data stored into BRAM  

Software reads BRAM to verify:

  - No dropped beats  
  - Correct ordering  
  - Correct `tlast` location  
  - Payload fidelity  
  - AXI-Stream `tvalid/tready` timing

---

### **Stage 3 — Final RDMA RX Integration**
The validated RX pipeline was connected to the complete RDMA decapsulation chain.

This integration demonstrated:

- Full-speed RX at 1 Gbps
- Correct RDMA header extraction
- DDR writes matching transmitted payload
- Consistent operation with real RDMA packets

This is the final configuration used in the project.

---

## 4. Key Technical Insights (Directly Learned from Ethernet Part)

These insights guide the later parts of the RDMA pipeline.

### **4.1 AXI-Stream Timing Is Very Important**
We learned through debugging that:

- while `ready=0` `valid` must remain high  
- `data` and `keep` **must not change**  

Our `axis_rx_to_rdma` module enforces this rule strictly.

Validator of decapsulator hangs the line for multiple clock cycles so it was important to keep the valid bit until that handshake happens. Otherwise, the first word of rdma header was lost which was opcode so the write DDR operation failed.

---

### **4.2 Ethernet Block Always Uses 125 MHz for gtx_clk (Even at 10/100 Mbps)**
The MAC *always* requires a 125 MHz clock, regardless of negotiated link speed.  
The PHY internally divides its clock to achieve 10/100 operation (not for our case since our ethernet ip block only supports 1 gbps ).

---

### **4.3 The MAC Does Not Autodetect Speed — PHY Negotiates, MAC Obeys**
We learned:

- PHY negotiates speed with link partner  
- MAC speed must be explicitly configured  
- RGMII timing always expects 125 MHz gtx_clk  


---

## 5. Documentation Structure

Ethernet MAC & PHY Subsytem is documented across several detailed sections:

- **AXI Ethernet MAC** – MAC configuration & internals
- **RGMII & PHY** – PHY electrical & logical behavior RGMMI explanations
- **MDIO** – MDIO logic and how we use it to reach PHY registers  
- **Clocking & Timing** – Clocking architecture  
- **AXIS RX/TX_to_RDMA Block** – Custom RX and TX pass through module controlling txd, txc, rxd, rxs pins of ethernet ip block
- **RX/TX Ethernet Tests** – TX RX tests separate from RDMA logic  
- **RDMA RX** – Final RDMA integration  


Each section focuses on a specific subtopic, and I explained everything as clearly and thoroughly as possible. I did not only cover the block design and its settings, but also the underlying logic and design principles. For this reason, I went through every relevant detail and compared the different interfaces, explaining why we use them and how they operate.



