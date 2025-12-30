# Section 4: Control Plane Architecture

## 4.1 Hardware / Software Interface Overview

The hardware-software interface in this RDMA proof-of-concept system is implemented via a single AXI4-Lite subordinate attached to the Zynq UltraScale+ Processing System (PS). The PS hosts bare-metal software executing on ARM Cortex-A53 cores, while the RDMA control and datapath logic resides in the Programmable Logic (PL). This architecture maintains a clear separation between control plane and data plane functions.

### 4.1.1 Interface Characteristics

The AXI4-Lite interface is strictly a control and synchronization channel. Payload data does not traverse this interface; instead, data movement occurs through dedicated AXI4-MM and AXI4-Stream channels managed by hardware DMA engines. The AXI4-Lite slave provides memory-mapped access to 32-bit wide registers, totaling 32 register locations at 4-byte boundaries within a 128-byte address aperture.

### 4.1.2 Control Plane Responsibilities

All operation progress and completion detection is performed via polling; no interrupt-driven control flow is implemented. The control plane interface enables software to perform the following operations:

- **Queue Configuration**: Initialize Send Queue (SQ) and Completion Queue (CQ) descriptor rings in system DDR memory by programming base addresses and queue depths.
- **Queue Synchronization**: Coordinate producer-consumer operations through head and tail pointer updates. Software advances tail pointers to post new work; hardware advances head pointers as work completes.
- **Doorbell Notification**: Signal hardware of new work availability through explicit doorbell writes that generate single-cycle pulse strobes to the control FSM.
- **Status Polling**: Read hardware-owned registers to monitor queue state, operation progress, and error conditions through polling-based operation.
- **Global Control**: Issue enable, reset, and mode control commands that govern operational state transitions in the PL logic.

### 4.1.3 Register Access Semantics

Register access patterns follow standard producer-consumer synchronization models. Software-writable registers (control, configuration, and software-owned pointers) support read-modify-write operations with byte-lane write strobing. Hardware-owned registers (status, hardware-owned pointers, and performance counters) are read-only from the software perspective and are directly driven by PL logic without intermediate buffering. Write attempts to hardware-owned registers are silently ignored by the AXI4-Lite slave logic.

Doorbell registers exhibit special write-triggered behavior: any write transaction to a doorbell register address, regardless of data value, generates a single-cycle pulse on the corresponding doorbell output signal. This pulse triggers queue processing logic in the RDMA controller FSM.

---

## 4.2 AXI-Lite Register Addressing Model

The register file spans 128 bytes (0x00 to 0x7C) and comprises 32 word-aligned 32-bit registers. Register addresses are byte-addressed with word alignment. The register space is logically partitioned into control, Send Queue (SQ), and Completion Queue (CQ) groups.

### 4.2.1 Register Address Map

| Offset | Name              | Access | Description                                      |
|--------|-------------------|--------|--------------------------------------------------|
| 0x00   | CONTROL           | RW     | Global enable, soft reset, pause, mode control   |
| 0x04   | HW_STATUS         | RO     | Hardware operational status word                 |
| 0x08   | IRQ_ENABLE        | RW     | Interrupt enable mask                            |
| 0x0C   | IRQ_STATUS        | W1C    | Interrupt status flags (write-1-to-clear)        |
| 0x10   | GLOBAL_CFG        | RW     | Global configuration parameters                  |
| 0x14   | RESERVED          | —      | Reserved for future use                          |
| 0x18   | RESERVED          | —      | Reserved for future use                          |
| 0x1C   | TEST_REG          | RW     | Test/debug register                              |
| 0x20   | SQ_BASE_LO        | RW     | Send Queue base address [31:0]                   |
| 0x24   | SQ_BASE_HI        | RW     | Send Queue base address [63:32]                  |
| 0x28   | SQ_SIZE           | RW     | Send Queue depth (number of entries)             |
| 0x2C   | SQ_HEAD           | RO     | Send Queue head pointer (HW-owned)               |
| 0x30   | SQ_TAIL           | RW     | Send Queue tail pointer (SW-owned, doorbell)     |
| 0x34   | SQ_DOORBELL       | WO     | Send Queue explicit doorbell trigger             |
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
RW = Read-Write | RO = Read-Only | WO = Write-Only | W1C = Write-1-to-Clear

### 4.2.2 Register Type Definitions

**Read-Write (RW) Registers**: These registers maintain state programmed by software and may be read back at any time. Write operations update the register value according to the AXI4-Lite write strobe signals (WSTRB). Reset behavior initializes these registers to zero unless otherwise specified.

**Read-Only (RO) Registers**: Hardware logic directly drives these registers. Read operations return the current value as determined by PL control logic. Write operations to these addresses are legal AXI transactions but have no architectural effect; the write data is discarded and the register value remains unchanged.

**Write-Only (WO) Registers**: These registers exist solely to trigger hardware side effects. The written data value is typically ignored; the write transaction itself serves as the control event. Software reads of write-only registers return zeros or indeterminate values and should be avoided.

### 4.2.3 Control Register (0x00)

The CONTROL register provides top-level operational control over the RDMA subsystem. This register contains implementation-internal bitfields for global enable, reset, and mode control. In the current proof-of-concept implementation, software initializes this register during system setup but does not actively manipulate individual control bits during normal operation.Software may initialize this register to a known state during system setup but does not manipulate individual control bits during normal operation.

### 4.2.4 Queue Base Address Registers

Queue base addresses are 64-bit physical DDR addresses split across two 32-bit registers (LO and HI). These addresses must point to pre-allocated, contiguous descriptor ring buffers in system memory. The controller uses these base addresses in conjunction with queue size parameters to compute descriptor addresses via modulo arithmetic.

For the Send Queue:
- **SQ_BASE_LO (0x20)**: Bits [31:0] of the 64-bit base address
- **SQ_BASE_HI (0x24)**: Bits [63:32] of the 64-bit base address

For the Completion Queue:
- **CQ_BASE_LO (0x40)**: Bits [31:0] of the 64-bit base address
- **CQ_BASE_HI (0x44)**: Bits [63:32] of the 64-bit base address

Software must ensure base address alignment is compatible with descriptor size and DMA engine burst alignment requirements.

### 4.2.5 Queue Size Registers

**SQ_SIZE (0x28)** and **CQ_SIZE (0x48)** define the number of entries in the respective descriptor rings. The hardware controller uses these values to implement wraparound logic when advancing head or tail pointers. A queue size of N allows indices in the range [0, N-1]. The queue full condition is detected when the producer pointer would equal the consumer pointer after advancing.

### 4.2.6 Queue Pointer Registers

Queue pointers implement producer-consumer synchronization:

- **SQ_HEAD (0x2C, RO)**: Hardware-owned. Incremented by the RDMA controller after fetching and initiating a Send Queue entry. Software polls this register to determine queue occupancy and drain status.

- **SQ_TAIL (0x30, RW)**: Software-owned. Incremented by software after posting a new descriptor to the Send Queue. Writing this register implicitly asserts the SQ_DOORBELL_PULSE signal for one clock cycle.

- **CQ_HEAD (0x4C, RW)**: Software-owned. Incremented by software after consuming a completion entry. This pointer informs hardware when CQ space is available for reuse.

- **CQ_TAIL (0x50, RO)**: Hardware-owned. Incremented by the RDMA controller after writing a completion entry to memory. Software polls this register to detect new completions.

Pointer values are indices (not byte addresses) and wrap to zero when incremented past SQ_SIZE or CQ_SIZE.

### 4.2.7 Doorbell Registers

Doorbell registers provide explicit notification mechanisms:

- **SQ_DOORBELL (0x34, WO)**: Writing any value to this address triggers hardware to re-evaluate SQ_HEAD versus SQ_TAIL and resume queue processing if work is available. This register allows doorbell assertion without modifying SQ_TAIL, useful in scenarios where the tail pointer was previously updated but hardware may not have processed all entries.

Write data to doorbell registers is discarded; only the write transaction itself is significant. The AXI4-Lite slave translates the write into a single-cycle pulse on internal control signals monitored by the RDMA controller FSM.

### 4.2.8 Debug and Reserved Registers

Several registers provide diagnostic visibility:

- **RDMA_STATE (0x5C)** and **CMD_STATE (0x60)** expose internal FSM state encodings, enabling software to diagnose stuck or unexpected controller behavior during development and debug.

- **RDMA_LOCAL_HI**, **RDMA_REMOTE_LO/HI**, and **RDMA_BTT_[0-3]** registers (0x64–0x7C) reflect latched RDMA descriptor fields captured by the controller. These registers support introspection of the currently processed operation.

Reserved register addresses and bit fields are implementation-specific placeholders. Software should write zero to reserved bits and ignore values read from reserved fields to ensure forward compatibility.

### 4.2.9 Access Guidelines

Software should observe the following access patterns:

1. **Initialization**: Program queue base addresses and sizes before setting CONTROL to an operational state.
2. **Work Submission**: Write descriptor(s) to DDR, perform memory barrier if necessary, then advance SQ_TAIL.
3. **Work Completion**: Poll CQ_TAIL for changes. When CQ_TAIL advances, read completion descriptor(s) from DDR, process, then advance CQ_HEAD.
4. **Reset Sequence**: Modify CONTROL register to assert reset, wait fixed interval (e.g., 100 µs), clear reset, then reprogram pointers to zero.

Access width must be 32-bit aligned. Unaligned or narrow (8/16-bit) accesses may result in undefined behavior depending on AXI4-Lite interconnect and slave configuration. Burst transactions are not supported; all accesses must be single-word transactions.

---

**End of Section 5**
