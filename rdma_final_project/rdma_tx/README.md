# RDMA TX Path

This directory contains the transmit path implementation for the RDMA engine.

## Directory Structure

```
rdma_tx/
├── Vivado/                     # FPGA design
│   ├── rdma_tx_project.tcl     # TCL script to recreate Vivado project
│   ├── src/                    # Verilog RTL source files
│   ├── bd/                     # Block design files
│   ├── ip/                     # Vivado IP configurations
│   ├── ip_repo/                # Custom IP repository
│   ├── tb/                     # Testbenches
│   ├── sim/                    # Simulation files
│   └── xdc/                    # Timing and pin constraints
│
└── Vitis/                      # Software
    ├── rdma_tx_app/            # Bare-metal application
    └── rdma_tx_kr260_platform/ # Hardware platform
```

## Quick Start

### Generate Vivado Project

```bash
cd Vivado
vivado -mode batch -source rdma_tx_project.tcl
```

Or in Vivado TCL console:
```tcl
cd <path_to>/rdma_tx/Vivado
source rdma_tx_project.tcl
```

### Build Flow

1. Open the generated `rdma_tx_project.xpr`
2. Run Synthesis → Implementation → Generate Bitstream
3. Export Hardware (File → Export → Export Hardware, include bitstream)
4. Open Vitis and create platform from exported `.xsa`

## RTL Modules

| File | Description |
|------|-------------|
| `rdma_axilite_ctrl.v` | AXI-Lite slave for queue registers and doorbell |
| `tx_streamer.v` | Fragmentation logic and DataMover command generation |
| `tx_header_inserter.v` | Serializes RDMA header (7 × 32-bit beats) |
| `rdma_ip_encap_integrated.v` | Wraps RDMA packets in UDP/IP/Ethernet headers |
| `ip_eth_tx_64_rdma.v` | Interfaces with AXI Ethernet MAC TX path |
| `rdma_meta_validator.v` | Validates RDMA metadata fields |
| `eth_pkt_gen.v` | Ethernet packet generator |

## Software Application

The `rdma_tx_app` contains bare-metal C code that:

1. Configures queue base addresses and sizes
2. Prepares payload data in DDR
3. Constructs SQ descriptors
4. Submits work via doorbell (SQ_TAIL write)
5. Polls CQ_TAIL for completions
6. Measures throughput

### Key Structures

```c
// 64-byte Submission Queue Entry
typedef struct {
    uint32_t id;
    uint16_t opcode;
    uint16_t flags;
    uint64_t local_key;   // Source DDR address
    uint64_t remote_key;  // Destination address
    uint32_t length_lo;
    uint32_t length_hi;
    uint32_t reserved[8];
} sq_entry_t;

// 32-byte Completion Queue Entry
typedef struct {
    uint32_t wqe_id;
    uint32_t status_opcode;
    uint32_t bytes_sent_lo;
    uint32_t bytes_sent_hi;
    uint32_t original_id;
    uint32_t original_length;
    uint32_t reserved1;
    uint32_t reserved2;
} cq_entry_t;
```

## Memory Map

| Buffer | Address | Size |
|--------|---------|------|
| SQ Buffer | 0x10000000 | Configurable |
| Remote Buffer | 0x20000000 | Configurable |
| Payload Buffer | 0x30000000 | Configurable |
| CQ Buffer | 0x40000000 | Configurable |
