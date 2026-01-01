# RDMA RX Path

This directory contains the receive path implementation for the RDMA engine.

## Directory Structure

```
rdma_rx/
├── Vivado/                     # FPGA design
│   ├── rdma_rx.tcl             # TCL script to recreate Vivado project
│   ├── src/                    # Verilog RTL source files
│   ├── bd/                     # Block design files
│   ├── ip/                     # Vivado IP configurations
│   ├── ip_repo/                # Custom IP repository
│   ├── tb/                     # Testbenches
│   ├── sim/                    # Simulation files
│   └── xdc/                    # Timing and pin constraints
│
└── Vitis/                      # Software
    ├── rdma_rx/                # Bare-metal application
    └── rdma_v1_platform/       # Hardware platform
```

## Quick Start

### Generate Vivado Project

```bash
cd Vivado
vivado -mode batch -source rdma_rx.tcl
```

Or in Vivado TCL console:
```tcl
cd <path_to>/rdma_rx/Vivado
source rdma_rx.tcl
```

### Build Flow

1. Open the generated `rdma_rx_final.xpr`
2. Run Synthesis → Implementation → Generate Bitstream
3. Export Hardware (File → Export → Export Hardware, include bitstream)
4. Open Vitis and create platform from exported `.xsa`

## RTL Modules

| File | Description |
|------|-------------|
| `rdma_axilite_rx_ctrl.v` | AXI-Lite slave for RX configuration |
| `rx_header_parser.v` | Extracts RDMA header (7 × 32-bit beats) |
| `rx_streamer.v` | Issues S2MM commands for payload writeback |
| `rdma_ip_decap_integrated.v` | Strips UDP/IP/Ethernet headers |
| `ip_eth_rx_64_rdma.v` | Interfaces with AXI Ethernet MAC RX path |
| `rdma_hdr_validator.v` | Validates received RDMA header fields |
| `axis_rx_to_rdma.v` | AXI-Stream adapter for RX data |

## Software Application

The `rdma_rx` application contains bare-metal C code that:

1. Initializes the AXI Ethernet MAC
2. Configures PHY via MDIO (auto-negotiation)
3. Sets MAC address
4. Monitors DDR region for received RDMA writes
5. Dumps received data for verification

### Key Functions

```c
// Initialize Ethernet MAC and PHY
static int InitEth(int *FoundPhyAddr);

// Dump DDR buffer contents for verification
static void DumpRemoteBuf(int max_words);
```

### PHY Configuration

The RX application configures the Gigabit Ethernet PHY:
- PHY Address: 2 (KR260 board specific)
- Speed: 1000 Mbps (auto-negotiation enabled)
- Registers: BMCR (control), BMSR (status)

## Memory Map

| Buffer | Address | Size |
|--------|---------|------|
| Remote Buffer | 0x20000000 | 64 KB |

This is where incoming RDMA WRITE operations place their payload data. The RX hardware computes the destination address as:

```
dest_addr = remote_addr_from_header + fragment_offset
```

## RX Data Flow

```
Ethernet PHY → AXI Ethernet MAC → IP Decapsulator → RX Header Parser → RX Streamer → DDR
```

1. **Ethernet MAC** receives frames and validates CRC
2. **IP Decapsulator** strips Ethernet/IP/UDP headers
3. **RX Header Parser** extracts 7-beat RDMA header
4. **RX Streamer** issues DataMover S2MM commands
5. **DataMover** writes payload to computed DDR address
