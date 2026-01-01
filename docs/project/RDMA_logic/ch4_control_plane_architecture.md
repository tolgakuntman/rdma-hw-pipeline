# Section 4: Control Plane Architecture

This section defines the AXI-Lite register interface that software uses to configure, control, and monitor the RDMA engine. It serves as a hardware programmer's reference for the control plane API.

---

## 4.1 Interface Overview

The control plane uses an AXI4-Lite slave interface providing memory-mapped access to 32-bit registers. This interface handles configuration and synchronization only; payload data moves through separate AXI4-MM and AXI4-Stream channels managed by hardware DMA engines.

| Property | Value |
|----------|-------|
| Interface | AXI4-Lite Slave |
| Data width | 32 bits |
| Address space | 128 bytes (0x00 to 0x7C) |
| Register count | 32 word-aligned registers |
| Completion model | Polling (no interrupts implemented) |

---

## 4.2 Register Map

### Address Map

| Offset | Name              | Access | Description                                      |
|--------|-------------------|--------|--------------------------------------------------|
| 0x00   | CONTROL           | RW     | Global enable, soft reset, pause, mode control   |
| 0x04   | HW_STATUS         | RO     | Hardware operational status word                 |
| 0x08   | IRQ_ENABLE        | RW     | Interrupt enable mask                            |
| 0x0C   | IRQ_STATUS        | RW     | Interrupt status flags                           |
| 0x10   | RESERVED          | RW     | Reserved for future use                          |
| 0x14   | RESERVED          | —      | Reserved for future use                          |
| 0x18   | RESERVED          | —      | Reserved for future use                          |
| 0x1C   | RESERVED          | -      | Reserved for future use                          |
| 0x20   | SQ_BASE_LO        | RW     | Submission Queue base address [31:0]             |
| 0x24   | SQ_BASE_HI        | RW     | Submission Queue base address [63:32]            |
| 0x28   | SQ_SIZE           | RW     | Submission Queue depth (number of entries)       |
| 0x2C   | SQ_HEAD           | RO     | Submission Queue head pointer                    |
| 0x30   | SQ_TAIL           | RW     | Submission Queue tail pointer (doorbell)         |
| 0x34   | RESERVED          | -      | Reserved for future use                          |
| 0x38   | RESERVED          | —      | Reserved for future use                          |
| 0x3C   | RESERVED          | —      | Reserved for future use                          |
| 0x40   | CQ_BASE_LO        | RW     | Completion Queue base address [31:0]             |
| 0x44   | CQ_BASE_HI        | RW     | Completion Queue base address [63:32]            |
| 0x48   | CQ_SIZE           | RW     | Completion Queue depth (number of entries)       |
| 0x4C   | CQ_HEAD           | RW     | Completion Queue head pointer (SW-owned)         |
| 0x50   | CQ_TAIL           | RO     | Completion Queue tail pointer (HW-owned)         |
| 0x54   | RESERVED          | —      | Reserved for future use                          |
| 0x58   | RESERVED          | —      | Reserved for future use                          |
| 0x5C   | RDMA_STATE        | RO     | RDMA controller FSM state (debug)                |
| 0x60   | CMD_STATE         | RO     | Command controller FSM state (debug)             |
| 0x64   | RDMA_LOCAL_HI     | RO     | RDMA entry local key [63:32]                     |
| 0x68   | RDMA_REMOTE_LO    | RO     | RDMA entry remote key [31:0]                     |
| 0x6C   | RDMA_REMOTE_HI    | RO     | RDMA entry remote key [63:32]                    |
| 0x70   | RDMA_BTT_0        | RO     | RDMA entry byte transfer count [31:0]            |
| 0x74   | RDMA_BTT_1        | RO     | RDMA entry byte transfer count [63:32]           |
| 0x78   | RDMA_BTT_2        | RO     | RDMA entry byte transfer count [95:64]           |
| 0x7C   | RDMA_BTT_3        | RO     | RDMA entry byte transfer count [127:96]          |

**Legend:**  
RW = Read-Write | RO = Read-Only | WO = Write-Only 

---

## 4.3 Register Access Semantics

### Read-Write (RW) Registers

- Maintain programmed state until modified
- Support byte-lane write strobing via WSTRB
- Initialize to zero on reset

### Read-Only (RO) Registers

- Driven directly by hardware logic
- Write transactions are accepted but have no effect
- Return current hardware state on read

### Doorbell Behavior

Writing to **SQ_TAIL (0x30)** generates a single-cycle pulse that triggers the RDMA controller to check for new work. The written value updates the tail pointer; the write transaction itself serves as the doorbell notification.

---

## 4.4 Register Descriptions

### CONTROL (0x00)

Global operational control register. Software initializes this register during system setup to enable the RDMA subsystem.

### Queue Base Address Registers

64-bit physical DDR addresses for queue descriptor rings, split across LO/HI register pairs:

| Queue | Low Register | High Register |
|-------|--------------|---------------|
| SQ | SQ_BASE_LO (0x20) | SQ_BASE_HI (0x24) |
| CQ | CQ_BASE_LO (0x40) | CQ_BASE_HI (0x44) |

Base addresses must point to pre-allocated, contiguous buffers in DDR. Alignment must be compatible with descriptor size (64 bytes for SQ, 32 bytes for CQ).

### Queue Size Registers

| Register | Offset | Description |
|----------|--------|-------------|
| SQ_SIZE | 0x28 | Number of SQ entries (determines index range [0, N-1]) |
| CQ_SIZE | 0x48 | Number of CQ entries (determines index range [0, N-1]) |

### Queue Pointer Registers

Pointer values are entry indices (not byte addresses). See [Section 3.2](ch3_hardware_architecture.md#32-queue-architecture-and-ownership) for ownership semantics.

| Register | Offset | Owner | Description |
|----------|--------|-------|-------------|
| SQ_HEAD | 0x2C | Hardware | Next SQ entry to fetch |
| SQ_TAIL | 0x30 | Software | Next SQ slot for new work (doorbell on write) |
| CQ_HEAD | 0x4C | Software | Next CQ entry to consume |
| CQ_TAIL | 0x50 | Hardware | Next CQ slot for completion |

### Debug Registers (0x5C–0x7C)

These registers expose internal state for diagnostic purposes:

| Register | Description |
|----------|-------------|
| RDMA_STATE | Current RDMA controller FSM state encoding |
| CMD_STATE | Current command controller FSM state encoding |
| RDMA_LOCAL_HI | Upper 32 bits of latched local address |
| RDMA_REMOTE_LO/HI | Latched remote address (64-bit) |
| RDMA_BTT_0–3 | Latched byte transfer count (128-bit) |

---

## 4.5 Programming Guidelines

### Initialization Sequence

1. Program SQ_BASE_LO, SQ_BASE_HI, SQ_SIZE
2. Program CQ_BASE_LO, CQ_BASE_HI, CQ_SIZE
3. Ensure SQ_TAIL = 0 and CQ_HEAD = 0
4. Set CONTROL register to enable operation

### Work Submission

1. Write descriptor to DDR at `SQ_BASE + (SQ_TAIL × 64)`
2. Flush cache for descriptor region
3. Write incremented tail value to SQ_TAIL (triggers doorbell)

### Completion Polling

1. Poll CQ_TAIL until `CQ_TAIL ≠ CQ_HEAD`
2. Invalidate cache for CQ entry region
3. Read completion from `CQ_BASE + (CQ_HEAD × 32)`
4. Write incremented head value to CQ_HEAD

### Access Constraints

| Constraint | Requirement |
|------------|-------------|
| Access width | 32-bit aligned only |
| Burst support | Single-word transactions only |
| Narrow access | 8/16-bit accesses may cause undefined behavior |
| Reserved fields | Write zero, ignore on read |