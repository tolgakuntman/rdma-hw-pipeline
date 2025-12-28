# RGMII & DP83867IR PHY

This chapter documents the RGMII-based Ethernet PHY used in the KR260 PL Ethernet interface and how it is configured and used together with the **AXI 1G/2.5G Ethernet Subsystem (PG138)** and our Vitis software. 

The focus is on:
- Different types of Media-independent interfaces (MII) and their properties
- What RGMII actually is (signals, timing, clocking).
- How the **The Texas Instruments DP83867IR** PHY on the KR260 is wired and configured.
- How the PHY and MAC (AXI Ethernet IP) interact to produce a working 1 Gbps link.

The PHY can be explained through its two main interfaces: MDIO and RGMII. I already have a separate section dedicated to MDIO, where I describe how the PHY is configured and how its status is monitored. This section will focus on RGMII, which is the primary data path between the MAC and the PHY and the most important connection between them. That is why I chose to include PHY in the title of this section instead of MDIO.

---

## 1. KR260 Ethernet Hardware Overview

The KR260 integrates two PL-based Gigabit Ethernet interfaces implemented through **RGMII** and connected to two discrete PHY devices. These interfaces form the physical entry point for all Ethernet frames used in our PL-side data pipeline.

This section summarizes the hardware components involved and how Ethernet signals reach the FPGA fabric.

---

### 1.1 PL-Side Ethernet Ports

According to the KR260 Carrier Card User Guide (UG1092), the PL exposes two RGMII-based Ethernet ports:

- **CC J10A** — “1 Gb/s Ethernet 3 (PL) – RGMII on HPB”
- **CC J10B** — “1 Gb/s Ethernet 2 (PL) – RGMII on HPA”

Each port is implemented using a dedicated **TI DP83867** Gigabit Ethernet PHY.

![kria](images/kria.png)

---

### 1.2 Electrical Path: RJ45 → PHY → FPGA

Each Ethernet interface consists of the following hardware path:

1. **RJ45 jack with integrated magnetics**  
   Provides isolation and differential coupling for 10/100/1000BASE-T.

2. **DP83867IR Gigabit PHY**  
   Converts copper Ethernet signaling into digital RGMII signals. Handles: Line coding / decoding , Auto-negotiation, and Speed selection (10/100/1000).

3. **RGMII interface into FPGA PL**  
      `rgmii_td[3:0]`, `rgmii_tx_ctl`, `rgmii_txc`  
      `rgmii_rd[3:0]`, `rgmii_rx_ctl`, `rgmii_rxc`  

4. **AXI 1G/2.5G Ethernet Subsystem (MAC)** 
   The MAC consumes RGMII signals and exposes:
   - AXI-Stream TX/RX interfaces  
   - MDIO management  
   - FCS generation and checking  
   - MAC address filtering  
 

![phy_app](images/PHY_application.png)

---

### 1.3 Relevant PHY Hardware Features

The DP83867 is a single port 10/100/1000 Ethernet PHY, that supports connections to an Ethernet MAC via RGMII or GMII. Connections to the Ethernet media are made via the IEEE 802 3 defined Media Dependent Interface. DP83867IRRGZ/CRRGZ support only RGMII.

The TI DP83867IR device provides several features essential to KR260 RGMII operation:

- **IEEE 802.3 10/100/1000 Mb/s support**
- **RGMII interface** with optional internal clock delays
- Internal PLL locked to a **25 MHz reference crystal**
- **MDIO/MDC** interface for configuration and status
   
   Strap pins determining:
  - PHY address  
  - RGMII/SGMII mode  
  - TX/RX delay defaults  
  - Autonegotiation behavior  


---

### 1.4 Block Design Integration

Inside the Vivado block design:

- The DP83867 RGMII pins route directly to the **AXI 1G/2.5G Ethernet Subsystem**.
- The MAC is configured explicitly for **RGMII operation**.
- `gtx_clk` (125 MHz) for the MAC is supplied via a Clocking Wizard.
- MDIO is connected for PHY management.

Later sections build on this hardware foundation by explaining RGMII signaling (Section 2), Vivado interfacing (Section 3), MDIO runtime configuration (Section 4), and PHY clocking/delay behavior (Section 5).

---

## 2. What is RGMII?

RGMII (Reduced Gigabit Media Independent Interface) is one member of the broader MII family of MAC–PHY interfaces, which define how an Ethernet MAC connects to an external PHY. The original MII (Media Independent Interface) supported 10/100 Mbps using a 4-bit data bus clocked at 25/2.5 MHz. As speeds increased, GMII (Gigabit MII) expanded this to an 8-bit bus clocked at 125 MHz, allowing 1 Gbps but requiring 24 signals—too many for compact boards. To reduce complexity, several “reduced” variants were introduced: RMII (Reduced MII) for 10/100 Mbps using only 2 data lines + 50 MHz clock, and RGMII (Reduced GMII) for 1 Gbps using only 4 data lines per direction. RGMII achieves the same throughput as GMII by using **double-data-rate (DDR)** signaling —transmitting data on both clock edges— cutting the pin count roughly in half.

---

### 2.1 RGMII Signal Set

**From the datasheet:**

The Reduced Gigabit Media Independent Interface (RGMII) is designed to reduce the number of pins required to interconnect the MAC and PHY (12 pins for RGMII relative to 24 pins for GMII). To accomplish this goal, the data paths and all associated control signals are reduced and are multiplexed. Both rising and trailing edges of the clock are used. For Gigabit operation the GTX_CLK and RX_CLK clocks are 125MHz, and for 10- and 100Mbps operation, the clock frequencies are 2.5MHz and 25MHz, respectively.

RGMII reduces the classic GMII interface from **8-bit data + multiple control pins** down to:

- **4-bit data bus per direction**  
- **1 control pin per direction**  
- **Separate TX and RX clocks**

To maintain full Gigabit throughput with only 4 bits, RGMII uses **DDR signaling**:

- **Rising edge** of the clock → lower 4 bits  
- **Falling edge** of the clock → upper 4 bits  

This effectively transfers 8 bits every 8 ns at 125 MHz → **1.0 Gbps**.

#### Transmit Path (MAC → PHY)

| Signal | Description |
|--------|-------------|
| `rgmii_td[3:0]` | 4-bit transmit data bus (DDR) |
| `rgmii_tx_ctl` | Encodes TX_EN and TX_ER |
| `rgmii_txc` | 125 MHz transmit clock generated by the MAC |

#### Receive Path (PHY → MAC)

| Signal | Description |
|--------|-------------|
| `rgmii_rd[3:0]` | 4-bit receive data bus (DDR) |
| `rgmii_rx_ctl` | Encodes RX_DV and RX_ER |
| `rgmii_rxc` | 125 MHz receive clock generated by the PHY |

These pins are visible in PL ethernet block.

![rgmii_mac](images/rgmii_MAC.png)


---

### 2.2 RGMII Speeds and Clocking Behavior

#### 1 Gbps Operation
- The MAC drives/receives data at **125 MHz DDR** on `rgmii_td[3:0]` / `rgmii_rd[3:0]`.
- Each 8 ns clock period carries 8 bits.
- Effective data rate: **1.0 Gbit/s** on the digital RGMII bus.

#### 100 Mbps and 10 Mbps Operation
When the RGMII interface is operating in the 100Mbps mode, the Ethernet Media Independent Interface (MII) is implemented by reducing the clock rate to 25MHz. For 10Mbps operation, the clock is further reduced to 2.5MHz. In the RGMII 10/100 mode, the transmit clock RGMII TX_CLK is generated by the MAC and the receive clock RGMII RX_CLK is generated by the PHY. During the packet receiving operation, the RGMII RX_CLK can be stretched on either the positive or negative pulse to accommodate the transition from the free-running clock to a data synchronous clock domain. When the speed of the PHY changes, a similar stretching of the positive or negative pulses is allowed. No glitch is allowed on the clock signals during clock speed transitions. This interface operates at 10- and 100Mbps speeds the same way as at 1000Mbps mode with the exception that the data can be duplicated on the falling edge of the appropriate clock. The MAC holds the RGMII TX_CLK low until the MAC has confirmed that the MAC is operating at the same speed as the PHY.

---

## 6. MAC Speed vs PHY Autonegotiation

One of the most commonly misunderstood parts of RGMII bring-up is **the relationship between the PHY's negotiated line speed** and **the MAC’s internal operating speed**.

On the KR260, the PHY (DP83867) handles autonegotiation with the link partner entirely in hardware.  
The MAC (AXI 1G/2.5G Ethernet Subsystem), however:

- **Does NOT automatically update its internal speed**
- **Does NOT read PHY speed from BMSR or vendor registers**
- **Relies 100% on software configuration**

This means:

> Even if the PHY negotiates 1000 Mbps, the MAC will not operate correctly unless the software configures it for 1000 Mbps.

---

### 6.1 How Autonegotiation Works (PHY Side)

The PHY negotiates *link speed* and *duplex* with the remote device via the 802.3 standard autonegotiation FSM.  
The DP83867 performs the following in hardware:

1. Advertises supported modes (10/100/1000, full-duplex, etc.)
2. Exchanges link code words with partner
3. Determines best common mode
4. Enables internal clocking paths for that mode
5. Sets status bits:
   - `BMSR[2]` — LINK_STATUS  

This entire process occurs **independently of the MAC**.

---

### 6.2 How the MAC Operates Internally

The MAC has **no ability to know PHY speed**.

Instead, it must be explicitly configured by software using:

```c
XAxiEthernet_SetOperatingSpeed(&EthInst, XAE_SPEED_1000_MBPS);
```

Supported values:

- `XAE_SPEED_10_MBPS`
- `XAE_SPEED_100_MBPS`
- `XAE_SPEED_1000_MBPS`

If this value does not match the negotiated PHY speed, the MAC will not function correctly.

In our project we always **forced the MAC to 1 Gbps mode**, because both of our kr260 aimed gigabit ethernet.

If we wanted to support 10/100 Mbps links as well, we would first read the negotiated speed from the PHY’s status registers over MDIO and then pass the corresponding XAE_SPEED_* value to XAxiEthernet_SetOperatingSpeed() instead of hard-coding XAE_SPEED_1000_MBPS. In our KR260 setup, we always run the link at 1 Gbps, so this dynamic speed handling is not needed.

---

### 6.3 Why the MAC Cannot Auto-Detect Speed

In typical SoC systems (PS GEM, Intel MAC, Broadcom MAC), PHY speed can be read via MDIO and MAC is updated automatically.

But the AXI Ethernet IP in the PL is different:

- It is **pure logic**, not a “smart” MAC with an embedded PHY driver.
- It has **no MDIO controller that interprets negotiation results**.
- It exposes MDIO pins, but does not analyze their data.
- It has no firmware inside it.

Thus, only software (running on the A53) knows how to:

- Read the PHY via MDIO  
- Interpret vendor registers  
- Update MAC speed  
- Reconfigure flow control, pause frames, etc.  

In other words:

> The PHY chooses the wire speed.  
> The MAC must be told what speed that is.

---

### 6.4 Our Design Decision: Always Force MAC to 1000 Mbps

On the KR260 PL Ethernet port, everything is gigabit-capable:

- DP83867 supports 1000BASE-T  
- RJ45 magnetics support 1 Gbps  
- Test PCs/switches support 1 Gbps  
- AXI Ethernet IP supports 1 Gbps RGMII mode  
- Clocking Wizard provides 125 MHz clocking regardless of wire speed

Thus we simplified the logic:

#### **Always configure the MAC for 1000 Mbps:**

```c
XAxiEthernet_SetOperatingSpeed(&EthInst, XAE_SPEED_1000_MBPS);
```

Even if the PHY negotiates 100 Mbps in some edge case:

- The MAC continues to run its internal logic at 1 Gbps mode  
- The PHY internally adjusts for line speed  
- RGMII timing still uses 125 MHz clock  
- The MAC sees normal RGMII DDR data  
- Packets continue to flow normally  

This works because:

> RGMII always uses 125 MHz clocks on the MAC side.  
> Speed reduction (100/10 Mbps) happens inside the PHY.

The DP83867 manages the adaptation.

---

### 6.5 But What If We Wanted Multi-Speed Support?

Then the firmware must:

1. Read PHY negotiated speed from PHY vendor registers  
2. Compare against the current MAC configuration  
3. Reconfigure MAC speed  
4. Reset / re-init AXI Ethernet subsystem  
5. Possibly reset RGMII interface  
6. Re-enable RX/TX paths

#### Speed detection example (pseudo-code):

```c
u16 phyStatus;
READ_PHY(PhyAddr, 0x11, &phyStatus);  // DP83867 speed/duplex vendor reg

int speed;
switch (phyStatus & SPEED_MASK) {
    case SPEED_1000: speed = XAE_SPEED_1000_MBPS; break;
    case SPEED_100:  speed = XAE_SPEED_100_MBPS;  break;
    case SPEED_10:   speed = XAE_SPEED_10_MBPS;   break;
}

XAxiEthernet_SetOperatingSpeed(&EthInst, speed);
```

KR260 does NOT require this because both ports are always gigabit.

---

### 6.6 Consequences of Speed Mismatch (Debugging Guide)

If the PHY negotiates 1 Gbps, but MAC is configured for 100 Mbps:

- RX packets may be corrupted  
- Inter-packet gap may be violated  
- Partner drops packets  
- AXI Ethernet RX side may report:
  - CRC errors  
  - alignment errors  
  - empty frames  
  - carrier sense issues  

If MAC is set faster than PHY:

- RX FIFO may overflow  
- Link may appear up but traffic fails  
- Wireshark captures garbage  
- AXI Ethernet may never assert `m_axis_rxd_tvalid`

Clear symptoms include:

#### **Symptom A — Link Up but No RX Packets**

Cause: MAC at wrong speed → internal IPG timing invalid.

#### **Symptom B — Many CRC Errors in Wireshark**

Cause: MAC samples RGMII data incorrectly.

#### **Symptom C — “Stuck” RX Path (valid=0 forever)**

Cause: MAC cannot align RGMII RX data stream.

#### **Symptom D — TX Works, RX Doesn’t**

Cause: TX timing tolerant to mismatch, RX intolerant.

---

### 6.7 Why RGMII Always Uses 125 MHz Regardless of Speed

This point is crucial:

> RGMII always uses a 125 MHz clock between MAC and PHY — even for 10/100 Mbps links.

The PHY simply **repeats** data at low rate:

- For 100 Mbps → transmits valid data only on rising edge  
- For 10 Mbps → repeats symbols for many cycles  
- Clock remains *always* 125 MHz

This means:

- The MAC internal logic must *always* assume gigabit timing  
- Only the PHY knows the real wire speed  
- The MAC cannot infer anything from RGMII clock alone  

This is why AXI Ethernet must be pegged to **1 Gbps mode** for RGMII.

---

### 6.8 Practical Bring-Up Sequence (Our KR260 Implementation)

Our firmware configures things in the only safe and stable order:

1. **Configure the MAC to 1000 Mbps**
   ```c
   XAxiEthernet_SetOperatingSpeed(&EthInst, XAE_SPEED_1000_MBPS);
   ```

2. **Enable autonegotiation on PHY**
   ```c
   bmcr |= BMCR_AUTONEG_EN | BMCR_RESTART_AN;
   ```

3. **Poll PHY link status**
   ```c
   if (Bmsr & BMSR_LINK_STATUS) { ... }
   ```

4. **Start RX/TX pipelines**
   ```c
   XAxiEthernet_Start(&EthInst);
   ```

This procedure guarantees:

- MAC internal clocking is stable  
- RGMII interface is timed correctly  
- PHY negotiates freely without interfering  
- AXI-Stream TX/RX state machines do not hang  

---

## 7. Reset, Power-Up, and Bring-Up Sequence

Correct RGMII bring-up depends on a very strict initialization order across:

- The board’s power rails  
- DP83867 strap sampling  
- 25 MHz reference stabilization  
- PHY reset signals  
- MAC configuration  
- MDIO initialization  
- Autonegotiation  
- RX/TX datapath activation  

If these steps occur in the wrong order, the RGMII link may appear *up*, but:

- RX path never receives data  
- RGMII clock edges are misaligned  
- Autoneg stalls  
- CRC/alignment errors appear  
- MAC AXI-Stream RX stays stuck in `tvalid=0` state

This section details the **exact correct sequence** for KR260 PL-Ethernet.

---

### 7.1 Power-Up Sequence of DP83867 (Board Level)

The DP83867 PHY has several dependencies that MUST stabilize before any communication can begin:

#### **1. Power rails**
According to DP83867 datasheet:
- `VDDA1P8` must reach stable levels before internal analog circuits lock.
- `VDDIO` powers RGMII I/O cells.
- `VDDA2P5` powers PLL and analog front end.

#### **2. 25 MHz reference**
The PHY’s internal PLL locks on the external **25 MHz crystal/oscillator**.

Before reset is released:
- The 25 MHz clock must be stable.
- The PHY must complete strap sampling.

#### **3. Strap Pin Latching**
During reset release, PHY samples configuration straps:

- PHY address  
- RGMII vs SGMII mode  
- TX/RX clock delays  
- LED behavior  
- Auto-MDIX

On KR260, these straps select:
- RGMII mode  
- Appropriate RGMII delays  
- Correct PHY addresses (each port has a unique address)  

> **NOTE (screenshot placeholder):** Insert KR260 schematic snippet showing DP83867 strap pins.

---

### 7.2 Reset Signals (PL Drives PHY Reset)

The KR260 carrier card routes **PHY reset lines** to the PL fabric.

The AXI Ethernet IP exposes:

```
phy_rst_n  (active LOW)
```

This is driven by the PL through:
- `proc_sys_reset`  
- AXI Ethernet internal logic

**Important:**  
The PHY reset pin MUST be held low long enough for strap sampling and power stabilization.  
Typical requirement (DP83867 datasheet): **10 ms minimum**.

KR260 satisfies this automatically, as `proc_sys_reset` asserts reset until PS/PL clocks stabilize.

---

### 7.3 Global Reset Ordering (MAC → PHY → MDIO)

A correct reset/bring-up sequencing is:

1. **Power rails come up**
2. **25 MHz ref clock stable**
3. **PHY held in reset (phy_rst_n = 0)**
4. **PL fabric configured / bitstream loaded**
5. **MAC initially in reset**
6. **Release PHY reset (phy_rst_n = 1)**
7. **PHY samples straps and begins autonegotiation**
8. **Software configures MAC**
9. **Software configures PHY via MDIO**
10. **MAC RX/TX enabled**
11. **RX clock begins toggling (RGMII RXC)**
12. **RX frames arrive into MAC**

If any of these occur out of order, the MAC may never lock to the PHY’s RGMII clock domain.

---

### 7.6 Observing Bring-Up Using Hardware

#### **Observation A — Check RJ45 LEDs**
- Link LED must be ON  
- Activity LED should blink upon TX/RX  

If LINK LED is off:
- Wrong PHY address  
- Autoneg disabled  
- Cable issue  
- Remote device down  
- PHY not out of reset  

---

#### **Observation B — Check MAC/PHY with MDIO Debugging**

## 8. RGMII Debugging Guide (KR260 + DP83867 + AXI Ethernet)

### 8.1 First Question: **Is the PHY Alive?**

Before touching the MAC, always confirm the PHY is actually responding.

#### Check 1 — MDIO Reads Return Valid Values

Run:

```c
XAxiEthernet_PhyRead(&EthInst, PhyAddr, PHY_REG_BMSR, &Bmsr);
```

Expected:

- Not `0xFFFF`
- Not `0x0000`
- It should be 2.

If you get `0xFFFF`:

- Wrong PHY address
- MDIO not connected
- PHY stuck in reset
- PHY has no power
- Something holding MDIO high-Z

---

### 8.2 Link LED Status Can Diagnose Half the Problems

On KR260:

- **Green LED** → link established (usually 1G)  
- **Yellow LED** → activity, autonegotiation, or 100/10 Mbit fallback  

If **both LEDs remain off**:

- Cable missing / bad  
- Switch port disabled  
- PHY still in reset  
- Autoneg disabled in BMCR  
- Strap configuration incorrect  
- 25 MHz clock not toggling  

---

### 8.4 Autonegotiation Debugging

The DP83867 autoneg FSM may fail silently.

#### Step 1 — BMSR Double-Read

```c
XAxiEthernet_PhyRead(&EthInst, PhyAddr, 1, &b1);
XAxiEthernet_PhyRead(&EthInst, PhyAddr, 1, &b2);

if (b2 & 0x0004)  
    xil_printf("Link Up\n");
```

If link never becomes UP:

- Switch port is locked to wrong mode (forced speed/duplex)
- Autoneg disabled in BMCR
- DONT FORCE SPEED in software — let PHY negotiate  
  (MAC speed is independent of PHY speed)

---

### 8.6 Debugging AXI Ethernet (MAC-Side Issues)

Even if RGMII is perfect, MAC may refuse RX due to misconfigurations.

#### Check — Did you call SetOperatingSpeed *before* enabling TX/RX?

Correct order:

```c
XAxiEthernet_SetOperatingSpeed(&EthInst, XAE_SPEED_1000_MBPS);
XAxiEthernet_SetOptions(&EthInst, Options);
XAxiEthernet_Start(&EthInst);
```

Calling `SetOperatingSpeed()` after Start() leads to:

- RX path stuck  
- TX working but RX silent  
- Invalid RGMII RX timing latched  