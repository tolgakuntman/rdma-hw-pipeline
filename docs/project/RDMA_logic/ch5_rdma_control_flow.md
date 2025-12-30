# Section 5: RDMA Control Flow

## 5.1 Overview of RDMA Operation

The RDMA controller implements a polling-based, descriptor-driven architecture that manages work submission, execution, and completion through memory-mapped queue structures. The operational flow is initiated by software posting work requests to the Send Queue (SQ) and concludes with hardware writing completion entries to the Completion Queue (CQ). This section describes the control flow from work submission through SQ entry acceptance.

The diagram below illustrates the system architecture and the primary communication flows between software, hardware modules, and memory:

{{include: figures/rdma_end_to_end_flow.mmd}}

The architecture comprises seven primary components: PS software running on ARM Cortex-A53 cores manages queue operations via AXI-Lite register access. The RDMA controller orchestrates descriptor fetch, parsing, and completion generation. The TX path constructs RDMA headers and manages payload streaming through DataMover MM2S operations. An elastic FIFO provides loopback buffering between transmit and receive paths. The RX path parses incoming headers and directs payload writes to DDR via DataMover S2MM operations. All queue structures and payload buffers reside in DDR memory, accessed through cache-coherent (PS side) and non-coherent DMA (PL side) paths.

Four primary flows govern operation: ① the control flow spans doorbell signaling through descriptor fetch and tx_cmd issuance; ② the TX data flow serializes 7-beat headers and payload streams into the loopback FIFO; ③ the RX data flow parses headers and writes payloads to destination addresses; ④ the completion flow writes CQ entries, updates pointers, and enables software polling detection.

### 5.1.1 Work Submission Model

Software prepares work by constructing 64-byte Send Queue descriptors in DDR memory at pre-configured queue locations. Each SQ descriptor encodes operation parameters including local memory addresses, remote memory addresses (in this loopback context, simulating remote targets), transfer lengths, and operation codes. After writing one or more descriptors to memory and ensuring cache coherency through explicit flush operations, software signals work availability to hardware by advancing the SQ_TAIL pointer via AXI-Lite register write.

The act of writing to the SQ_TAIL register (offset 0x30) serves dual purposes: it updates the software-owned tail pointer value and implicitly generates a single-cycle doorbell pulse to the RDMA controller FSM. Alternatively, software may write to the explicit SQ_DOORBELL register (offset 0x34) to assert the doorbell signal without modifying the tail pointer value. This mechanism supports scenarios where multiple descriptors are posted in batch and a single doorbell assertion is sufficient to trigger hardware processing.

### 5.1.2 Work Detection and Queue Management

The RDMA controller continuously monitors the relationship between hardware-owned SQ_HEAD and software-owned SQ_TAIL pointers to determine work availability. The controller maintains an internal `has_work` signal computed as:

```
has_work = (SQ_HEAD ≠ SQ_TAIL)
```

When the head and tail pointers differ, the queue is non-empty and contains at least one unprocessed descriptor. The queue full condition, conversely, is detected when incrementing the tail pointer would make it equal to the head pointer. This circular queue management employs modulo arithmetic based on the programmed SQ_SIZE value, allowing pointer wraparound from the last entry back to index zero.

The controller's finite state machine remains in an idle state until both the global enable signal is asserted (via CONTROL register bit) and work is detected. Upon satisfying these conditions, the FSM transitions to initiate SQ descriptor fetch operations.

### 5.1.3 System-Level Control Flow

The complete operation cycle from software submission to hardware completion acknowledgment proceeds as follows:

1. **Descriptor Preparation**: Software constructs SQ descriptor(s) in allocated DDR buffer at address `SQ_BASE + (tail_index × 64)`.

2. **Cache Coherency**: Software executes data cache flush operations to ensure descriptor visibility to hardware DMA engines.

3. **Doorbell Ring**: Software writes new tail value to SQ_TAIL register, generating doorbell pulse and making work visible to hardware.

4. **Work Detection**: Hardware controller detects `SQ_HEAD ≠ SQ_TAIL` condition and identifies available work.

5. **Descriptor Fetch**: Controller initiates read transaction to retrieve 64-byte descriptor from DDR.

6. **Descriptor Parse**: Retrieved descriptor is parsed into constituent fields (opcode, addresses, length, flags).

7. **Operation Execution**: Controller orchestrates data movement operations based on parsed descriptor (details in subsequent sections).

8. **Completion Write**: Upon operation completion, controller writes 32-byte completion descriptor to CQ in DDR.

9. **Pointer Update**: Controller increments SQ_HEAD, making the queue slot available for reuse and signaling consumption to software.

10. **Completion Processing**: Software polls CQ_TAIL register, detects advancement, reads completion descriptor from DDR, and advances CQ_HEAD.

This architecture decouples submission from completion, allowing pipelined operation where software may post additional work while hardware processes previously submitted descriptors.

---

## 5.2 Submission Queue Processing

The RDMA controller's SQ processing logic is implemented as a multi-state finite state machine that coordinates descriptor fetch, parsing, validation, and acceptance. This section details the control path from work detection through descriptor acquisition and field extraction.

### 5.2.1 Descriptor Fetch Initiation

When the controller detects available work and receives the global enable signal, it transitions from the idle state (S_IDLE) to the descriptor read preparation state (S_PREPARE_READ). In this state, the controller computes the physical DDR address of the descriptor to be fetched using the current SQ_HEAD pointer value:

```
descriptor_address = SQ_BASE_ADDR + (SQ_HEAD << 6)
```

The left-shift by 6 bits (equivalent to multiplication by 64) accounts for the fixed 64-byte descriptor size. The SQ_BASE_ADDR is the 64-bit base address programmed via SQ_BASE_LO and SQ_BASE_HI registers during queue initialization. This address calculation occurs combinationally during the prepare state, establishing the source address for the subsequent memory read command.

The controller also configures the byte transfer count (BTT) to exactly 64 bytes and sets the operation direction flag to indicate a read operation (memory-to-stream). These parameters are registered and held stable for the command issuing phase.

### 5.2.2 Memory Read Command Issuance

Upon entering the read command state (S_READ_CMD), the controller asserts a start pulse to the command generation logic when the command interface signals readiness. This start pulse, combined with the pre-calculated source address and BTT parameters, initiates a memory read transaction through the system's DMA infrastructure.

The command interface employs a ready-valid handshake protocol. The controller asserts the command valid signal for a single cycle when the command controller indicates readiness. Once the handshake completes, the FSM advances to the wait state (S_WAIT_READ_DONE) and monitors for read completion signaling.

The issued memory read command triggers the AXI DataMover MM2S (Memory-Mapped to Stream) channel to fetch 64 bytes from the computed DDR address. The DataMover converts this memory data into an AXI4-Stream transaction that will be delivered to the descriptor parser.

### 5.2.3 Descriptor Stream Reception and Parsing

The descriptor arrives at the slave stream parser module as a sequence of sixteen 32-bit AXI4-Stream transfers (16 words × 4 bytes = 64 bytes). The parser implements a simple two-state FSM that accumulates incoming words into an internal buffer until all sixteen words are received, as indicated by the TLAST signal on the final word.

Upon receiving the complete 64-byte descriptor, the parser extracts fields according to the defined SQ entry structure:

- **Word 0** [bytes 0-3]: WQE ID (`rdma_id`)
- **Word 1** [bytes 4-7]: Opcode [15:0] and Flags [31:16] (`rdma_opcode`, `rdma_flags`)
- **Words 2-3** [bytes 8-15]: Local key / local DDR address (`rdma_local_key`)
- **Words 4-5** [bytes 16-23]: Remote key / remote address (`rdma_remote_key`)
- **Words 6-9** [bytes 24-39]: Byte transfer count, lower 128 bits (`rdma_btt`)
- **Words 10-15** [bytes 40-63]: Reserved / extended fields (`rdma_reserved`)

The parser asserts a single-cycle `rdma_entry_valid` pulse when field extraction completes. This pulse serves as the synchronization signal that informs the RDMA controller FSM that parsed descriptor fields are stable and ready for consumption.

### 5.2.4 Descriptor Field Latching

The RDMA controller monitors the `rdma_entry_valid` signal while in the S_WAIT_READ_DONE and subsequent states. When this valid pulse is detected, the controller latches the parsed descriptor fields into internal registers:

- `rdma_id_reg`: Captured from parsed `rdma_id` field
- `rdma_opcode_reg`: Captured from parsed `rdma_opcode` field (lower 16 bits)
- `rdma_local_key_reg`: Captured from parsed `rdma_local_key` (64-bit local address)
- `rdma_remote_key_reg`: Captured from parsed `rdma_remote_key` (64-bit remote address)
- `rdma_length_reg`: Captured from `rdma_btt[31:0]` (lower 32 bits of transfer length)

These latched values remain stable throughout the operation's execution, serving as the authoritative source for subsequent data movement and completion generation phases. The latching operation decouples descriptor fetch timing from operation execution timing, allowing the controller FSM to progress through operation stages without re-referencing the original DDR descriptor location.

### 5.2.5 Descriptor Acceptance Criteria

A descriptor is considered accepted by hardware when the controller successfully advances past the descriptor fetch and parse phases. Acceptance is implicitly indicated by FSM progression from S_WAIT_READ_DONE to S_IS_STREAM_BUSY (and beyond), which occurs only after:

1. The memory read operation completes (`READ_COMPLETE` signal asserts)
2. The descriptor parser asserts `rdma_entry_valid`
3. The controller latches all descriptor fields into internal registers

At this point, the descriptor has been consumed from the SQ and the operation is committed to execution. The SQ_HEAD pointer, however, is not incremented until the entire operation completes (including data movement and CQ entry write). This deferred head pointer update implements a conservative queue management policy where a descriptor slot is considered occupied until its operation fully completes and the completion is written.

Software may infer descriptor acceptance by monitoring SQ_HEAD advancement through polling. If SQ_HEAD has not advanced after a reasonable timeout period, software may conclude that hardware has stalled or encountered an error. The design does not provide explicit per-descriptor acceptance acknowledgment signals; acceptance is implicit in the forward progress of the SQ_HEAD pointer.

### 5.2.6 Queue Pointer Wraparound

Both SQ_HEAD and SQ_TAIL employ circular queue semantics with automatic wraparound. When a pointer reaches the value `SQ_SIZE - 1` and is incremented, it wraps to zero rather than advancing to `SQ_SIZE`. The wraparound logic is computed as:

```
next_pointer = (current_pointer + 1 == SQ_SIZE) ? 0 : (current_pointer + 1)
```

This modulo arithmetic ensures that queue indices remain within the valid range [0, SQ_SIZE-1] and allows the queue buffer to be treated as a circular ring. Software must allocate a contiguous DDR buffer of size `SQ_SIZE × 64 bytes` at the SQ_BASE_ADDR location to accommodate the full ring.

The queue empty condition (`SQ_HEAD == SQ_TAIL`) and queue full condition (`(SQ_TAIL + 1) mod SQ_SIZE == SQ_HEAD`) are mutually exclusive states that govern whether new work may be posted or processed. The controller will not attempt descriptor fetch when the queue is empty (no work available), and software must not advance SQ_TAIL when the queue is full (no free slots available).

### 5.2.7 Error Handling and Timeout Considerations

The current implementation does not incorporate explicit timeout mechanisms or error recovery logic within the SQ processing path. The controller FSM assumes that memory read operations will eventually complete and that the descriptor parser will successfully extract fields from well-formed descriptors.

In production deployments, software is responsible for implementing watchdog timers and timeout detection. If SQ_HEAD fails to advance within an expected time window after posting work, software may infer a hardware fault condition. Recovery typically involves asserting the soft reset bit in the CONTROL register, re-initializing queue pointers, and re-posting affected work.

Malformed descriptors with invalid addresses or out-of-range transfer lengths may cause undefined behavior in downstream data movement engines. The descriptor fetch and parse logic does not validate field values; it is software's responsibility to ensure descriptor correctness before posting to the SQ.

---

## 5.3 RDMA Header Construction

Following descriptor acceptance and field latching, the RDMA controller issues a transmit command to the tx_streamer module, which subsequently programs a dedicated header insertion module to serialize RDMA metadata fields into AXI-Stream beats. This section describes the exact header structure, field-to-descriptor mapping, and serialization sequence as implemented in hardware.

### 5.3.1 Descriptor-to-Header Field Mapping

The RDMA controller extracts header fields from the latched descriptor registers and presents them via the tx_cmd interface. The exact mappings from descriptor words to transmitted header fields are:

| **Header Field** | **Source Register** | **Bits** | **Origin in Descriptor** |
|------------------|---------------------|----------|--------------------------|
| Opcode | `rdma_opcode_reg[7:0]` | 8 | Descriptor Word 1, bits [7:0] |
| Destination QP | `rdma_id_reg[23:0]` | 24 | Descriptor Word 0, bits [23:0] |
| Remote Address | `rdma_remote_key_reg[63:0]` | 64 | Descriptor Words 4-5 (bytes 16-23) |
| Remote Key | `rdma_remote_key_reg[31:0]` | 32 | Lower 32 bits of Words 4-5 |
| Length | `rdma_length_reg[31:0]` | 32 | Descriptor Words 6-9 lower bits (bytes 24-27) |
| DDR Address (local) | `rdma_local_key_reg[31:0]` | 32 | Descriptor Words 2-3 lower bits (bytes 8-11) |
| SQ Index | `sq_head_reg[7:0]` | 8 | Current hardware SQ pointer (not from descriptor) |

Additional fixed-value fields programmed by the controller:
- **Partition Key**: Constant `0xFFFF` (16 bits) — not derived from descriptor
- **Service Level**: Constant `0x00` (8 bits) — not derived from descriptor  
- **PSN**: Constant `0x000001` (24 bits) — not derived from descriptor

The controller assigns these values in `rdma_controller.v` (lines 213-222):
```verilog
assign tx_cmd_opcode         = rdma_opcode_reg[7:0];
assign tx_cmd_dest_qp        = rdma_id_reg[23:0];
assign tx_cmd_remote_addr    = rdma_remote_key_reg;
assign tx_cmd_rkey           = rdma_remote_key_reg[31:0];
assign tx_cmd_length         = rdma_length_reg;
assign tx_cmd_ddr_addr       = rdma_local_key_reg[31:0];
assign tx_cmd_sq_index       = sq_head_reg[7:0];
assign tx_cmd_partition_key  = 16'hFFFF;
assign tx_cmd_service_level  = 8'h00;
assign tx_cmd_psn            = 24'h000001;
```

### 5.3.2 Header Capture and Latching

The tx_streamer module captures these fields from the tx_cmd interface when the ready-valid handshake completes (`tx_cmd_valid && tx_cmd_ready`). The streamer latches all command fields into internal registers during the IDLE→INIT_FRAGMENT state transition:

```verilog
cmd_sq_index_reg       <= tx_cmd_sq_index;
cmd_ddr_addr_reg       <= tx_cmd_ddr_addr;
cmd_length_reg         <= tx_cmd_length;
cmd_opcode_reg         <= tx_cmd_opcode;
cmd_dest_qp_reg        <= tx_cmd_dest_qp;
cmd_remote_addr_reg    <= tx_cmd_remote_addr;
cmd_rkey_reg           <= tx_cmd_rkey;
cmd_partition_key_reg  <= tx_cmd_partition_key;
cmd_service_level_reg  <= tx_cmd_service_level;
cmd_psn_reg            <= tx_cmd_psn;
```

After latching, the streamer progresses through fragmentation logic (if enabled) and eventually programs the tx_header_inserter by driving the header field outputs in the PROGRAM_HEADER state. The header inserter captures these fields when the `start_tx` pulse asserts (`tx_header_inserter.v`, lines 125-145):

```verilog
if (start_tx && state_reg == STATE_IDLE) begin
    rdma_opcode_reg        <= rdma_opcode;
    rdma_psn_reg           <= rdma_psn;
    rdma_dest_qp_reg       <= rdma_dest_qp;
    rdma_remote_addr_reg   <= rdma_remote_addr;
    rdma_rkey_reg          <= rdma_rkey;
    rdma_length_reg        <= rdma_length;
    rdma_partition_key_reg <= rdma_partition_key;
    rdma_service_level_reg <= rdma_service_level;
    fragment_id_reg        <= fragment_id;
    more_fragments_reg     <= more_fragments;
    fragment_offset_reg    <= fragment_offset;
end
```

Note: The header inserter also latches fragmentation-related fields (fragment_id, more_fragments, fragment_offset), which are provided by the tx_streamer's fragmentation logic but not used in single-fragment transmissions.

### 5.3.3 Seven-Beat Header Serialization

The tx_header_inserter serializes the captured fields into exactly **seven 32-bit AXI-Stream beats**. The serialization order and field packing are defined in the STATE_SEND_HEADER case statement (`tx_header_inserter.v`, lines 199-229):

| **Beat Index** | **Bits [31:24]** | **Bits [23:16]** | **Bits [15:8]** | **Bits [7:0]** |
|----------------|------------------|------------------|-----------------|----------------|
| 0 | PSN[23:16] | PSN[15:8] | PSN[7:0] | Opcode[7:0] |
| 1 | 8'h00 | Dest_QP[23:16] | Dest_QP[15:8] | Dest_QP[7:0] |
| 2 | Remote_Addr[31:24] | Remote_Addr[23:16] | Remote_Addr[15:8] | Remote_Addr[7:0] |
| 3 | 16'h0000 (reserved) | Frag_Offset[15:8] | Frag_Offset[7:0] |
| 4 | Length[31:24] | Length[23:16] | Length[15:8] | Length[7:0] |
| 5 | 16'h0000 (reserved) | Part_Key[15:8] | Part_Key[7:0] |
| 6 | 24'hABABAB (constant) | Service_Level[7:0] |

Corresponding Verilog code:
```verilog
case (header_beat_count_reg)
    4'd0: m_axis_tdata_reg = {rdma_psn_reg, rdma_opcode_reg};
    4'd1: m_axis_tdata_reg = {8'd0, rdma_dest_qp_reg};
    4'd2: m_axis_tdata_reg = rdma_remote_addr_reg[31:0];
    4'd3: m_axis_tdata_reg = {16'h0000, fragment_offset_reg};
    4'd4: m_axis_tdata_reg = {rdma_length_reg};
    4'd5: m_axis_tdata_reg = {16'h0000, rdma_partition_key_reg};
    4'd6: m_axis_tdata_reg = {24'hababab, rdma_service_level_reg};
endcase
```

**Total Header Size**: 7 beats × 4 bytes/beat = **28 bytes** (224 bits transmitted, though only 208 bits contain meaningful fields).

**TKEEP Encoding**: All beats assert `TKEEP = 4'b1111`, indicating all four byte lanes are valid.

**TLAST Handling**: The header beats transmit with `TLAST = 0`. TLAST is asserted only on the final beat of the subsequent payload stream, not on the header.

### 5.3.4 Header-to-Payload Transition

The header inserter implements a three-state FSM (`tx_header_inserter.v`):
- **IDLE**: Wait for `start_tx` pulse
- **SEND_HEADER**: Stream 7 header beats, incrementing beat counter on each `m_axis_tready` assertion
- **SEND_DATA**: Pass-through mode, relaying DataMover MM2S output directly to master interface

The state transition from SEND_HEADER to SEND_DATA occurs when `header_beat_count_reg == 6` (the seventh beat, zero-indexed) and the master asserts TREADY to accept beat 6. At this point, the inserter:
1. Asserts `state_next = STATE_SEND_DATA`
2. Connects slave-side signals (`s_axis_tdata`, `s_axis_tkeep`, `s_axis_tvalid`, `s_axis_tlast`) directly to master-side outputs
3. Propagates backpressure by driving `s_axis_tready = m_axis_tready`

The critical sequencing is enforced by the tx_streamer, which:
1. Issues `start_tx` pulse to header inserter (entering STATE_START_HEADER)
2. Waits one cycle for header transmission to begin
3. Issues MM2S command to DataMover (STATE_ISSUE_DM_CMD), which begins reading payload from DDR
4. Monitors `mm2s_rd_xfer_cmplt` to detect payload stream completion (STATE_WAIT_DM_STS)
5. Monitors `hdr_tx_done` to confirm header inserter returned to idle (STATE_WAIT_HDR_DONE)

This ensures that the DataMover's payload stream arrives at the header inserter's slave interface only after header beats 0-6 have been transmitted, preventing payload data from overtaking header data.

### 5.3.5 Fragmentation Support (Implemented but Not Mandatory)

The tx_streamer includes fragmentation logic that respects 4 KB address boundaries and a configurable `BLOCK_SIZE` parameter (default 4096 bytes). For payloads exceeding these limits, the streamer:
- Computes fragment length: `min(remaining_bytes, BLOCK_SIZE, bytes_to_4KB_boundary)`
- Programs header inserter with **current fragment length** (not total payload length)
- Issues MM2S command for current fragment's address and length
- Updates `fragment_id`, `fragment_offset`, and `more_fragments` fields for subsequent fragments
- Repeats PROGRAM_HEADER→ISSUE_DM_CMD cycle for each fragment

Each fragment receives its own 7-beat header, with incremented `fragment_id` and adjusted `fragment_offset`. The receiver must reassemble fragments based on these fields (reassembly logic not covered here).

For payloads ≤4 KB and aligned addresses, only a single fragment is transmitted, and fragmentation fields are:
- `fragment_id = 0`
- `fragment_offset = 0`
- `more_fragments = 0`

### 5.3.6 Completion Signaling

The header inserter asserts `tx_done` when:
1. The FSM enters STATE_SEND_DATA (header transmission complete)
2. The payload stream completes (`s_axis_tlast && s_axis_tvalid && s_axis_tready`)
3. The FSM transitions back to IDLE

The tx_streamer monitors this signal in STATE_WAIT_HDR_DONE and only advances to STATE_UPDATE_STATE after both:
- `mm2s_rd_xfer_cmplt == 1` (DataMover finished reading DDR)
- `hdr_tx_done == 1` (Header inserter finished streaming)

This dual-completion check ensures the entire header+payload packet has been transmitted before the streamer reports operation completion to the RDMA controller.

---

## 5.4 DataMover Control and Payload Transfer

The RDMA controller orchestrates three distinct DataMover operations: (1) SQ descriptor fetch, (2) payload read from DDR for transmission, and (3) CQ entry write to DDR. This section describes the command generation, completion detection, and flow control mechanisms for each operation type as implemented in hardware.

### 5.4.1 DataMover Command Abstraction Layer

The design employs a unified command controller module (`data_mover_axi_cmd_master.v`) that abstracts the AXI DataMover's dual-channel interface (MM2S for reads, S2MM for writes). This abstraction accepts simplified control inputs:
- **Source Address** (`saddr`): DDR address for read operations
- **Destination Address** (`daddr`): DDR address for write operations  
- **Byte Transfer Count** (`btt`): Number of bytes to transfer (up to 8 MB, 23-bit field)
- **Direction Flag** (`is_read`): 1 = MM2S (memory read), 0 = S2MM (memory write)
- **Start Pulse** (`start`): Single-cycle command trigger

The command controller implements a 4-state FSM:
- **IDLE**: Wait for start pulse
- **SEND_CMD**: Assert appropriate command interface (MM2S or S2MM) for one cycle
- **WAIT_MM2S**: Monitor `mm2s_rd_xfer_cmplt` for read completion
- **WAIT_S2MM**: Monitor `s2mm_wr_xfer_cmplt` for write completion

### 5.4.2 DataMover Command Format (72-bit)

The command controller constructs 72-bit command words conforming to the Xilinx AXI DataMover IP specification. The format is identical for both channels, with address interpretation differing:

```
[71:64]  Reserved (8'b0)
[63:32]  Address (32-bit DDR byte address)
[31]     Type (1'b0 = fixed address, unused in this design)
[30]     DSA (1'b1 = deterministic slave address, always set)
[29:24]  Reserved (6'b0)
[23]     EOF (1'b1 = end of frame, always set for single-command transfers)
[22:0]   BTT (Bytes To Transfer, up to 8388607 bytes)
```

For MM2S (read) commands:
```verilog
m_axis_mm2s_cmd_tdata = {8'b0, saddr[31:0], 1'b0, 1'b1, 6'b0, 1'b1, btt[22:0]};
```

For S2MM (write) commands:
```verilog
m_axis_s2mm_cmd_tdata = {8'b0, daddr[31:0], 1'b0, 1'b1, 6'b0, 1'b1, btt[22:0]};
```

The command valid signal (`m_axis_*_cmd_tvalid`) is asserted for exactly one cycle in the SEND_CMD state when the captured `dir_reg` matches the channel direction.

### 5.4.3 SQ Descriptor Fetch (MM2S Operation #1)

The RDMA controller initiates descriptor fetch in the S_PREPARE_READ state by computing the descriptor address:
```verilog
cmd_ctrl_src_addr_r <= SQ_BASE_ADDR[31:0] + (sq_head_reg << 6);
cmd_ctrl_btt_r      <= 64;  // Fixed descriptor size
cmd_ctrl_is_read_r  <= 1'b1;  // MM2S direction
```

In the subsequent S_READ_CMD state, when the command controller signals readiness (`CMD_CTRL_READY == 1`), the RDMA controller asserts `cmd_ctrl_start_r` for one cycle:
```verilog
if (CMD_CTRL_READY) begin
    cmd_ctrl_start_r   <= 1'b1;
    cmd_ctrl_is_read_r <= 1'b1;
end
```

The command controller samples these parameters, transitions to SEND_CMD, and drives:
```
m_axis_mm2s_cmd_tdata  = {8'b0, (SQ_BASE + SQ_HEAD×64)[31:0], 14'b0_1_000000_1, 23'd64}
m_axis_mm2s_cmd_tvalid = 1
```

The DataMover's MM2S channel accepts this command, reads 64 bytes from the computed address, and streams the data to the slave stream parser module via 16 consecutive 32-bit AXI-Stream beats (TDATA[31:0], TVALID, TREADY, TLAST on beat 16).

**Completion Detection**: The command controller monitors `mm2s_rd_xfer_cmplt`, which asserts for one cycle when the DataMover finishes reading all 64 bytes. This signal is relayed as `READ_COMPLETE` to the RDMA controller, which detects it in S_WAIT_READ_DONE and advances to S_IS_STREAM_BUSY once the descriptor parser also asserts `rdma_entry_valid`.

### 5.4.4 Payload Read for Transmission (MM2S Operation #2)

Unlike descriptor fetch, payload read commands are **not issued by the RDMA controller**. Instead, the tx_streamer module issues payload commands directly to its own DataMover MM2S interface.

When the tx_streamer receives the tx_cmd from the controller (captured in IDLE→INIT_FRAGMENT transition), it extracts:
- `cmd_ddr_addr_reg` ← `tx_cmd_ddr_addr` (payload source address)
- `cmd_length_reg` ← `tx_cmd_length` (total payload bytes)

The streamer computes the first fragment parameters:
```verilog
first_chunk_to_boundary = BOUNDARY_4KB - (cmd_ddr_addr_reg & (BOUNDARY_4KB - 1));
first_chunk_by_block    = (cmd_length_reg > BLOCK_SIZE) ? BLOCK_SIZE : cmd_length_reg;
first_chunk_len         = min(first_chunk_by_block, first_chunk_to_boundary);
```

In STATE_ISSUE_DM_CMD, the streamer drives its MM2S command interface:
```verilog
mm2s_addr_reg  <= current_addr_reg;
mm2s_btt_reg   <= chunk_len_reg[22:0];
mm2s_valid_reg <= 1;
```

The command word construction is performed by the streamer's output assignment:
```verilog
assign m_axis_mm2s_cmd_tdata = {8'b0, mm2s_addr_reg[31:0], 1'b0, 1'b1, 6'b0, 1'b1, mm2s_btt_reg[22:0]};
assign m_axis_mm2s_cmd_tvalid = mm2s_valid_reg;
```

This command directs the DataMover to read `chunk_len` bytes from `current_addr` and stream them to the tx_header_inserter's slave interface.

**Fragment Iteration**: If the payload exceeds the computed chunk length, the streamer transitions through:
1. STATE_WAIT_DM_STS: Wait for `mm2s_rd_xfer_cmplt`
2. STATE_WAIT_HDR_DONE: Wait for `hdr_tx_done`
3. STATE_UPDATE_STATE: Advance address/offset counters, compute next chunk length
4. Loop back to STATE_PROGRAM_HEADER if `remaining_len_reg > chunk_len_reg`

Each iteration issues a new MM2S command for the next fragment's address and length. The fragmentation respects:
- **4 KB Alignment**: Chunks never cross 4 KB address boundaries (`current_addr & 0xFFF` wraps to 0x000 at boundary)
- **Block Size Limit**: Chunks ≤ `BLOCK_SIZE` parameter (default 4096 bytes)
- **Remaining Length**: Final chunk is clamped to remaining bytes

### 5.4.5 Payload Stream Backpressure Handling

The DataMover's MM2S output connects to the tx_header_inserter's slave interface. The header inserter controls backpressure propagation:

**During Header Transmission** (STATE_SEND_HEADER):
```verilog
s_axis_tready_reg = 0;  // Block payload acceptance
m_axis_tvalid_reg = 1;  // Stream header beats
```
The DataMover's output data stalls in its internal FIFOs while the header beats transmit.

**During Payload Pass-Through** (STATE_SEND_DATA):
```verilog
s_axis_tready_reg = m_axis_tready;  // Propagate downstream backpressure
m_axis_tvalid_reg = s_axis_tvalid;  // Pass through payload valid
m_axis_tdata_reg  = s_axis_tdata;   // Pass through payload data
```
If the loopback receiver (rx_streamer) cannot accept data, it deasserts TREADY on the header inserter's master interface. The inserter propagates this backpressure to the DataMover by deasserting its slave-side TREADY, causing the DataMover to pause streaming.

**TLAST Handling**: The DataMover asserts TLAST on the final beat of the payload stream. The header inserter relays this signal in pass-through mode:
```verilog
m_axis_tlast_reg = s_axis_tlast;
```
The receiver detects TLAST to determine packet boundaries. After observing TLAST with valid/ready handshake, the header inserter transitions to IDLE and asserts `tx_done = 1`.

### 5.4.6 Completion Queue Write (S2MM Operation)

After the tx_streamer reports transmission completion (`tx_cpl_valid` asserted), the RDMA controller transitions to S_PREPARE_WRITE and constructs the CQ entry. The controller builds an 8-word (32-byte) CQ descriptor in internal registers (`cq_entry_reg_0` through `cq_entry_reg_7`):

**CQ Entry Format**:
```
Word 0: {24'b0, tx_cpl_sq_index[7:0]}           // SQ index for correlation
Word 1: {24'b0, tx_cpl_status[7:0]}             // Status code (0 = success)
Word 2: tx_cpl_bytes_sent[31:0]                  // Bytes transmitted
Word 3: {24'b0, tx_cpl_sq_index[7:0]}           // Duplicate index field
Word 4: rdma_id_reg[31:0]                        // Original descriptor ID
Word 5: rdma_length_reg[31:0]                    // Original requested length
Word 6: 32'b0                                     // Reserved
Word 7: 32'b0                                     // Reserved
```

These registers are populated in the S_PREPARE_WRITE state (`rdma_controller.v` lines 176-190).

The controller then computes the CQ entry destination address:
```verilog
cmd_ctrl_dst_addr_r <= CQ_BASE_ADDR[31:0] + (cq_tail_reg << 5);
cmd_ctrl_btt_r      <= 32;  // Fixed CQ entry size
cmd_ctrl_is_read_r  <= 1'b0;  // S2MM direction
```

In S_WRITE_CMD, when ready, the controller issues the write command:
```verilog
if (CMD_CTRL_READY) begin
    cmd_ctrl_start_r   <= 1'b1;
    cmd_ctrl_is_read_r <= 1'b0;
end
```

The command controller generates:
```
m_axis_s2mm_cmd_tdata  = {8'b0, (CQ_BASE + CQ_TAIL×32)[31:0], 14'b0_1_000000_1, 23'd32}
m_axis_s2mm_cmd_tvalid = 1
```

Concurrently, in S_START_STREAM, the controller asserts `start_stream_r` for one cycle, triggering the master stream module to begin streaming the 8-word CQ entry. The master stream module drives:
```
M_AXIS_TDATA:  cq_entry_reg_0, cq_entry_reg_1, ..., cq_entry_reg_7 (sequential)
M_AXIS_TVALID: 1 (for 8 cycles)
M_AXIS_TLAST:  1 (on 8th word)
```

The DataMover's S2MM channel receives this stream and writes the 32 bytes to the computed CQ address in DDR.

**Completion Detection**: The DataMover asserts `s2mm_wr_xfer_cmplt` for one cycle when the write finishes. The command controller relays this as `WRITE_COMPLETE`, which the RDMA controller detects in S_WAIT_WRITE_DONE. Upon detecting completion, the controller atomically:
1. Increments `cq_tail_reg` (modulo CQ_SIZE)
2. Increments `sq_head_reg` (modulo SQ_SIZE)
3. Transitions to S_IDLE

This dual-pointer update makes the CQ entry visible to software (via CQ_TAIL register read) and frees the SQ slot for reuse.

### 5.4.7 Error Handling and Unspecified Behaviors

**Current Implementation Limitations**:
- The RDMA controller does not monitor DataMover error outputs (internal error flags, decode errors, timeout conditions).
- The tx_streamer sets `tx_cpl_status = 0` (success) unconditionally; no error path exists.
- Address range validation is absent; software must ensure DDR addresses are valid.
- No timeout detection for stalled DataMover operations.

**Potential Error Conditions Not Handled**:
- DDR address decode failure (out-of-range address)
- AXI protocol violations (unaligned bursts, illegal burst lengths)
- DataMover internal FIFO overflow/underflow
- Memory controller timeout (DDR refresh conflicts, thermal throttling)

**Questions for Clarification** (not specified in provided code):
1. What happens if `mm2s_rd_xfer_cmplt` never asserts? (No timeout mechanism observed)
2. How does the system recover from a stalled DataMover? (No watchdog timer in RTL)
3. Are there DataMover error status outputs that should be monitored? (Error signals not connected in `data_mover_controller.v`)

**Production Deployment Considerations**:
- Extend command controller to monitor DataMover's `mm2s_err` and `s2mm_err` outputs
- Implement timeout counters in WAIT_READ_DONE, WAIT_DM_STS, WAIT_WRITE_DONE states
- Propagate error status to CQ entry Word 1 status field
- Add address range validation logic comparing command addresses against configured DDR limits
- Software should implement watchdog polling: if SQ_HEAD fails to advance within expected time, assert soft reset

---

**End of Section 5.4**

## 5.8 End-to-End RDMA Transaction Timeline

The complete RDMA operation flow spans multiple clock domains and hardware-software boundaries, from initial work submission through payload transfer to completion polling. The diagram below synthesizes the control and data paths described in Sections 6.1–6.7 into a unified transaction timeline.

{{include: rdma_end_to_end_flow.mmd}}

### 5.8.1 Reading the Transaction Flow

The diagram depicts the sequential stages of a single RDMA WRITE operation as it progresses through the system's five primary components: PS software, the AXI-Lite register interface, the PL transmit path, the loopback FIFO, and the PL receive path. Key synchronization points govern the flow:

**Submission Synchronization** (Section 5.1-6.2): The transaction initiates when software writes the SQ_TAIL register, which generates a doorbell pulse detected by the rdma_controller FSM. This pulse triggers descriptor fetch via DataMover MM2S channel #1, reading 64 bytes from the computed SQ address. The descriptor parser's `rdma_entry_valid` pulse latches fields into controller registers, committing the operation for execution.

**Header-Payload Serialization** (Section 5.3-6.4): The tx_streamer issues two operations: (1) programming the tx_header_inserter to serialize seven 32-bit header beats containing opcode, addresses, and length fields, and (2) commanding DataMover MM2S channel #2 to read payload from DDR. The header inserter enforces ordering—header beats 0-6 transmit first, followed by payload pass-through. TLAST assertion on the final payload beat marks the packet boundary, signaling completion to both the tx_streamer and downstream receiver.

**Loopback and Reception** (Section 5.5): The axis_data_fifo provides elastic buffering, absorbing burst-mode traffic and preserving TLAST across the TX-RX boundary. The rx_header_parser accumulates seven beats, extracts fields when `beat_count=6`, and asserts `header_valid` to notify the rx_streamer. The streamer validates the opcode, computes the destination address as `remote_addr + fragment_offset`, and issues an S2MM command to DataMover channel #2, directing payload write to DDR. This RX path operates autonomously—no completion is reported back to the rdma_controller or software.

**Completion and Polling** (Section 5.6-6.7): When the tx_streamer detects MM2S completion (`mm2s_rd_xfer_cmplt`), it asserts `tx_cpl_valid`, triggering the rdma_controller to populate CQ entry registers (see Section 5.6 for format details). The controller streams the 32-byte CQ entry via DataMover S2MM channel #1, atomically increments both CQ_TAIL and SQ_HEAD, and returns to idle. Software polls the CQ_TAIL register until advancement is detected, invalidates cache lines covering the CQ entry, reads the completion status and byte count from DDR, and advances CQ_HEAD to free the slot.

**Cache Coherency Boundaries**: The diagram emphasizes four cache management operations mandated by the ARM Cortex-A53 + PL fabric architecture: (1) flush SQ descriptor before doorbell ring, (2) flush payload source buffer before MM2S read, (3) invalidate CQ entry before software read, and (4) invalidate destination buffer before payload verification. These operations bridge the cache-coherent PS domain and the non-coherent PL DMA path, preventing stale data reads and ensuring visibility of hardware-written completions.

The legend box reiterates design constraints: this proof-of-concept implements polling-only completion detection (no interrupts), omits remote key authentication (no rkey validation), and does not rely on CONTROL register reset sequences beyond system-level reset. The 7-beat header structure (28 bytes) and TLAST-based packet framing are fundamental to the operation, enabling the receiver to distinguish header metadata from payload data without additional out-of-band signaling.

---

**End of Section 5.8**

## 5.5 Loopback FIFO and RX Parsing

The receive path implements the inverse of the transmit header insertion logic, extracting RDMA metadata from the incoming stream and directing payload data to DDR memory. The loopback design employs an AXI-Stream FIFO to buffer packets between the transmit header inserter output and the receive header parser input, providing elastic buffering.

### 5.5.1 Loopback Interconnect Topology

The system's block design instantiates an AXI4-Stream Data FIFO IP (`axis_data_fifo_0`) positioned between transmit and receive modules:

```
tx_header_inserter.m_axis → axis_data_fifo_0.S_AXIS
axis_data_fifo_0.M_AXIS → rx_header_parser.s_axis
```

This FIFO serves multiple purposes:
- **Rate Matching**: Absorbs burst-mode traffic from TX side and delivers at steady rate to RX
- **Backpressure Buffering**: Provides elasticity when RX processing temporarily stalls
- **Packet Boundary Preservation**: Maintains TLAST signaling across the buffer

The FIFO operates in standard mode with TREADY/TVALID handshaking on both interfaces. The FIFO depth and other configuration parameters are set in the block design instantiation but are not exposed in the provided source files.

**Not specified in provided code**: FIFO depth, clock domain crossing configuration, overflow/underflow error handling.

### 5.5.2 RX Header Parser FSM

The rx_header_parser module (`rx_header_parser.v`) implements a three-state FSM that extracts RDMA header fields from the incoming stream:

**State Definitions**:
- `STATE_IDLE`: Wait for incoming packet (TVALID assertion)
- `STATE_PARSE_HEADER`: Accumulate 7 header beats into internal buffer
- `STATE_FORWARD_DATA`: Pass-through payload to downstream consumer

The parser operates as an AXI-Stream bridge, accepting data on its slave interface and forwarding it on its master interface after header extraction.

### 5.5.3 Seven-Beat Header Accumulation

When the parser detects TVALID in STATE_IDLE, it transitions to STATE_PARSE_HEADER and begins accumulating header beats. A 3-bit beat counter (`header_beat_count`) tracks progression from beat 0 to beat 6:

```verilog
if ((state_reg == STATE_IDLE || state_reg == STATE_PARSE_HEADER) && s_axis_hs) begin
    header_buf[header_beat_count] <= s_axis_tdata;
    if (header_beat_count < HEADER_BEATS-1) begin
        header_beat_count <= header_beat_count + 1'b1;
    end
end
```

Each 32-bit beat is stored in the `header_buf` array (7 entries, indexed 0-6). During this accumulation phase, the parser asserts `s_axis_tready` to accept data but does not drive the master interface (TX downstream is blocked).

### 5.5.4 Header Field Extraction

When `header_beat_count` reaches 6 (the seventh beat, zero-indexed), the parser extracts fields from the buffered beats in the following clock cycle. The extraction mirrors the TX packing order:

| **Beat** | **Extracted Fields** | **Assignment** |
|----------|----------------------|----------------|
| 0 | `rdma_opcode` ← `header_buf[0][7:0]` | Opcode (8 bits) |
| 0 | `rdma_psn` ← `header_buf[0][31:8]` | PSN (24 bits) |
| 1 | `rdma_dest_qp` ← `header_buf[1][23:0]` | Dest QP (24 bits) |
| 2 | `rdma_remote_addr[31:0]` ← `header_buf[2]` | Remote addr lower 32 bits |
| 3 | `fragment_offset` ← `header_buf[3][15:0]` | Fragment offset (16 bits) |
| 4 | `rdma_length` ← `header_buf[4]` | Payload length (32 bits) |
| 5 | `rdma_partition_key` ← `header_buf[5][15:0]` | Partition key (16 bits) |
| 6 | `rdma_service_level` ← `header_buf[6][7:0]` | Service level (8 bits) |

Code implementation from rx_header_parser.v:
```verilog
if (header_beat_count == HEADER_BEATS-1) begin
    rdma_opcode  <= header_buf[0][7:0];
    rdma_psn     <= header_buf[0][31:8];
    rdma_dest_qp <= header_buf[1][23:0];
    rdma_remote_addr <= {32'd0, header_buf[2]};
    fragment_offset <= header_buf[3][15:0];
    rdma_length <= header_buf[4];
    rdma_partition_key <= header_buf[5][15:0];
    rdma_service_level <= header_buf[6][7:0];
    
    header_valid <= 1'b1;  // Pulse to downstream consumers
end
```

The `header_valid` signal pulses for one cycle to notify downstream modules (rx_streamer) that extracted fields are stable and ready for consumption. The FSM simultaneously transitions to STATE_FORWARD_DATA.

**Note**: The 7-beat header does not include a remote key (rkey) field. The remote address field extracted from beat 2 is used by the RX streamer as the destination DDR address, but no separate authentication key is transmitted or validated.

### 5.5.5 Payload Pass-Through and TLAST Handling

After header extraction completes, the parser enters STATE_FORWARD_DATA and becomes transparent to the payload stream. In this state, the combinational logic directly connects slave-side signals to master-side outputs:

```verilog
STATE_FORWARD_DATA: begin
    m_axis_tdata  = s_axis_tdata;
    m_axis_tkeep  = s_axis_tkeep;
    m_axis_tvalid = s_axis_tvalid;
    m_axis_tlast  = s_axis_tlast;
    
    s_axis_tready_reg = m_axis_tready;  // Propagate backpressure
    
    if (s_axis_tvalid && m_axis_tready && s_axis_tlast) begin
        state_next = STATE_IDLE;
    end
end
```

The parser monitors for TLAST on the payload stream. When TLAST is observed with a valid handshake (TVALID && TREADY), the parser interprets this as the end of the current packet and returns to STATE_IDLE, ready to parse the next packet's header.

**Packet Boundary Delineation**: TLAST serves as the sole mechanism for packet boundary detection. The loopback design assumes that:
1. The DataMover's MM2S channel asserts TLAST on the final beat of payload data
2. The tx_header_inserter relays this TLAST in pass-through mode
3. The FIFO preserves TLAST across buffering
4. The rx_header_parser propagates TLAST to the rx_streamer

This signaling ensures that each RDMA packet (header + payload) is processed as an atomic unit.

### 5.5.6 RX Streamer WRITE Operation Processingthe extracted fields immediately:

```verilog
if (header_valid) begin
    opcode_reg    <= rdma_opcode;
    dest_addr_reg <= rdma_remote_addr[C_ADDR_WIDTH-1:0];
    length_reg    <= rdma_length;
    fragment_offset_reg <= fragment_offset;
    header_pending <= 1;  // Flag for FSM processing
end
```

The streamer implements a 5-state FSM:
- `STATE_IDLE`: Wait for `header_pending` flag
- `STATE_CHECK_OPCODE`: Verify opcode indicates WRITE operation
- `STATE_PREPARE_CMD`: Compute S2MM destination address
- `STATE_ISSUE_DM_CMD`: Send S2MM command to DataMover
- `STATE_WAIT_COMPLETE`: Monitor `s2mm_wr_xfer_cmplt`

**Opcode Filtering**: The streamer checks if the received opcode matches any WRITE variant defined as parameters in the module:
```verilog
wire is_write_op = (opcode_reg == RDMA_OPCODE_WRITE_FIRST)  ||
                   (opcode_reg == RDMA_OPCODE_WRITE_MIDDLE) ||
                   (opcode_reg == RDMA_OPCODE_WRITE_LAST)   ||
                   (opcode_reg == RDMA_OPCODE_WRITE_ONLY)   ||
                   (opcode_reg == RDMA_OPCODE_WRITE_TEST);  // Test opcode 0x01
```

The module parameters define these opcode constants (0x06, 0x07, 0x08, 0x0A for standard RDMA WRITE variants, plus 0x01 as a custom test opcode). If the received opcode does not match a WRITE operation, the streamer returns to IDLE without issuing any S2MM command. The payload data continues to be forwarded by the parser but is effectively discarded as no DataMover command directs

If the opcode does not match a WRITE operation, the streamer returns to IDLE without issuing any command. The payload data is still forwarded by the parser but is effectively discarded as no S2MM command is issued to write it to DDR.

### 5.5.7 S2MM Command Generation for Payload Write

When a valid WRITE opcode is detected, the streamer computes the destination DDR address by adding the fragment offset to the base address:

```verilog
s2mm_addr_reg <= dest_addr_reg + fragment_offset_reg;
s2mm_btt_reg  <= length_reg[C_BTT_WIDTH-1:0];
```

This address calculation supports fragmented payloads where each fragment specifies an offset relative to the original remote address field. For single-fragment transfers, `fragment_offset_reg` is zero.

The streamer constructs a 72-bit S2MM command with the same format as MM2S commands:
```verilog
assign m_axis_s2mm_cmd_tdata = {8'b0, s2mm_addr_reg[31:0], 1'b0, 1'b1, 6'b0, 1'b1, s2mm_btt_reg[22:0]};
assign m_axis_s2mm_cmd_tvalid = (state_reg == STATE_ISSUE_DM_CMD);
```

The DataMover's S2MM channel receives this command and begins accepting payload data from the rx_header_parser's master interface, writing it to the specified DDR address. The S2MM operation runs concurrently with payload streaming—the parser forwards payload beats while the DataMover writes them to DDR.

### 5.5.8 Backpressure and Flow Control

The rx_header_parser's pass-through mode preserves end-to-end flow control. If the DataMover's S2MM channel cannot accept payload data (due to DDR congestion or internal buffering limits), it deasserts TREADY on the parser's master interface. The parser propagates this backpressure upstream by deasserting its slave-side TREADY, which causes the FIFO to stop draining, which eventually propagates back to the tx_header_inserter.

This backpressure chain prevents data loss and ensures that no beats are dropped even if RX processing stalls temporarily. The FIFO provides buffering capacity to absorb short-term rate mismatches, but sustained backpressure will eventually stall the TX side.

**Completion Detection**: The rx_streamer monitors `s2mm_wr_xfer_cmplt` from the DataMover. When this signal asserts (single-cycle pulse), the streamer confirms that all payload bytes have been written to DDR and returns to IDLE. The streamer asserts a `write_complete` pulse that could be used for debugging or status reporting, but in the current loopback design, this signal is not connected to any completion queue or status register.

**Note**: The RX side operates autonomously without coordination with the TX-side RDMA controller. The rdma_controller has no visibility into RX operations; it only manages the TX path (SQ processing, payload read, CQ write). The loopback design validates that a packet transmitted by TX arrives correctly at RX and is written to the expected DDR location, but RX completion is not reported back to the controller or to software via any mechanism.

---

## 5.6 Completion Queue Generation and Writeback

Following successful transmission of header and payload, the RDMA controller constructs a Completion Queue entry that reports operation status to software. This section describes CQ entry formation, the DataMover S2MM write operation that commits the entry to DDR, and the pointer update mechanism that makes completions visible to software.

### 5.6.1 CQ Entry Structure and Format

The Completion Queue entry is a fixed-size 32-byte structure consisting of eight 32-bit words. The format is defined by the CQ entry registers in rdma_controller and corresponds to the software structure in `main.c`:

```c
typedef struct {
    uint32_t wqe_id;          // Word 0: SQ index that completed
    uint32_t status_opcode;   // Word 1: Status[7:0] | Opcode[15:8] | Reserved[31:16]
    uint32_t bytes_sent_lo;   // Word 2: Bytes  byte + reserved bits
    uint32_t bytes_sent_lo;   // Word 2: Bytes transferred
    uint32_t bytes_sent_hi;   // Word 3: Reserved/debug field
    uint32_t original_id;     // Word 4: Original WQE ID from descriptor
    uint32_t original_length; // Word 5: Original requested length
    uint32_t reserved1;       // Word 6: Reserved
    uint32_t reserved2;       // Word 7: Reserved
} cq_entry_t;
```

**Word-by-Word Description**:
- **Word 0** (`wqe_id`): The SQ index (SQ_HEAD value) of the completed work queue entry. Software uses this for correlation if multiple operations are in flight. Populated from `tx_cpl_sq_index` from the tx_streamer completion interface: `{24'd0, tx_cpl_sq_index}`.
  
- **Word 1** (`status_opcode`): In the current implementation, only bits [7:0] contain the status code (0 = success). The upper 24 bits are zero. The field is named `status_opcode` in software for forward compatibility, but no opcode echo is implemented. Populated as: `{24'd0, tx_cpl_status}`.

- **Word 2** (`bytes_sent_lo`): Total bytes transmitted, reported by the tx_streamer. For the current design, this is the complete byte count as 32-bit lengths are supported. Populated from: `tx_cpl_bytes_sent`.

- **Word 3** (`bytes_sent_hi`): The software structure names this field as if it were upper 32 bits of a 64-bit byte count, but the hardware implementation populates it with a duplicate copy of the SQ index: `{24'd0, tx_cpl_sq_index}`. This appears to be a debug or placeholder field rather than an actual upper byte count.

- **Word 4** (`original_id`): Echo of the WQE ID from the original SQ descriptor Word 0. This is the application-level identifier that software assigned to the work request. Populated from: `rdma_id_reg`.

- **Word 5** (`original_length`): Echo of the requested payload length from the SQ descriptor. Allows software to verify that the requested and transferred byte counts match. Populated from: `rdma_length_reg`.

- **Words 6-7**: Reserved, currently populated with zeros
### 5.6.2 CQ Entry Population Timing

The RDMA controller populates the CQ entry registers in the S_PREPARE_WRITE state, which is entered immediately after detecting `tx_cpl_valid` from the tx_streamer (indicating transmission completion). The population occurs in a single clock cycle (`rdma_controller.v`, lines 176-190):
:

```verilog
if (state_reg == S_PREPARE_WRITE) begin
    cq_entry_reg_0 <= {24'd0, tx_cpl_sq_index};
    cq_entry_reg_1 <= {24'd0, tx_cpl_status};
    cq_entry_reg_2 <= tx_cpl_bytes_sent;
    cq_entry_reg_3 <= {24'd0, tx_cpl_sq_index};  // Duplicate of SQ index
    cq_entry_reg_5 <= rdma_length_reg;
    cq_entry_reg_6 <= 32'd0;
    cq_entry_reg_7 <= 32'd0;
end
```

This timing ensures that completion metadata is captured at the correct instant—after the tx_streamer confirms that all fragments have been transmitted and the DataMover has completed reading payload from DDR, but before the CQ write operation begins. The latched descriptor fields (`rdma_id_reg`, `rdma_length_reg`) remain stable throughout the operation and are still available in S_PREPARE_WRITE for inclusion in the CQ entry.

### 5.6.3 CQ Entry DDR Address Calculation

The destination address for the CQ entry in DDR is computed based on the current CQ_TAIL pointer value. The address calculation occurs in the S_PREPARE_WRITE state, using the same pointer-to-address mapping as SQ descriptor fetch:

```verilog
cmd_ctrl_dst_addr_r <= CQ_BASE_ADDR[31:0] + (cq_tail_reg << CQ_DESC_SHIFT);
```

Where:
- `CQ_BASE_ADDR`: 64-bit base address of CQ ring buffer, programmed via CQ_BASE_LO/HI registers
- `cq_tail_reg`: Current hardware-owned tail pointer (range 0 to CQ_SIZE-1)
- `CQ_DESC_SHIFT`: Constant 5 (log₂(32), since each CQ entry is 32 bytes)

Example: If `CQ_BASE_ADDR = 0x20000000` and `cq_tail_reg = 3`, then:
```
CQ_entry_addr = 0x20000000 + (3 << 5) = 0x20000000 + 96 = 0x20000060
```

The controller also sets the byte transfer count to exactly 32 and the operation direction to write (S2MM):
```verilog
cmd_ctrl_btt_r     <= CQ_DESC_BYTES;  // 32
cmd_ctrl_is_read_r <= 1'b0;           // Write operation
```

### 5.6.4 Streaming CQ Entry to DataMover S2MM

The CQ entry write employs the same DataMover S2MM mechanism used for any memory write, but the data source is the master stream module (`data_mover_controller_master_stream_v1_0_M00_AXIS.v`) rather than an external stream.

**Initiation Sequence**:
1. Controller enters S_WRITE_CMD and asserts `cmd_ctrl_start_r` pulse when command controller is ready
2. Command controller generates S2MM command and asserts `m_axis_s2mm_cmd_tvalid`
3. Controller transitions to S_START_STREAM and asserts `start_stream_r` pulse
4. Master stream module captures the eight CQ entry register values into internal buffer
5. Master stream FSM transitions from IDLE to SEND_STREAM state

**Stream Transmission**: The master stream module operates as a simple AXI-Stream master that sequences through its buffered data. It maintains a read pointer (0-7) and drives TDATA with the corresponding buffered word:

```verilog
assign axis_tvalid = ((mst_exec_state == SEND_STREAM) && (read_pointer < NUMBER_OF_OUTPUT_WORDS));
assign axis_tlast = (read_pointer == NUMBER_OF_OUTPUT_WORDS-1);
```

Each word is transmitted when the DataMover asserts TREADY. The module increments the read pointer on each successful handshake:
```verilog
if (tx_en)  // tx_en = M_AXIS_TREADY && axis_tvalid
    stream_data_out <= data_buffer[read_pointer];
```

TLAST is asserted on the eighth word (read_pointer == 7), signaling to the DataMover that this is the final beat of the CQ entry. The DataMover's S2MM channel writes all eight words sequentially to the computed DDR address, completing the CQ entry commit.

### 5.6.5 Completion Detection and Pointer Updates

The RDMA controller monitors the `s2mm_wr_xfer_cmplt` signal from the DataMover, which the command controller relays as `WRITE_COMPLETE`. This signal asserts for one cycle when the DataMover finishes writing all 32 bytes to DDR.

When WRITE_COMPLETE is detected in state S_WAIT_WRITE_DONE, the controller performs an **atomic dual-pointer update**:

```verilog
if ((state_reg == S_WAIT_WRITE_DONE) && WRITE_COMPLETE) begin
    cq_tail_reg <= cq_tail_next;
    sq_head_reg <= sq_head_next;
end
```

Where:
```verilog
cq_tail_next = (cq_tail_reg + 1 == CQ_SIZE) ? 0 : (cq_tail_reg + 1);
sq_head_next = (sq_head_reg + 1 == SQ_SIZE) ? 0 : (sq_head_reg + 1);
```

This single-cycle update has two effects:

1. **CQ_TAIL Increment**: Advances the hardware-owned tail pointer, making the newly written CQ entry visible to software. Software polls this read-only register to detect completion availability.

2. **SQ_HEAD Increment**: Frees the SQ descriptor slot, allowing software to reuse it for a new work request. This increment signals to software that the descriptor has been fully consumed and its operation has completed.

The atomic nature of this update is critical: the CQ entry must be fully committed to DDR before either pointer advances. Otherwise, software might detect the advanced CQ_TAIL, read garbage from DDR (if CQ write incomplete), or attempt to reuse the SQ slot while hardware is still processing the descriptor.

### 5.6.6 Wraparound and Queue Full Conditions

Both CQ_TAIL and SQ_HEAD employ modulo arithmetic with wraparound at CQ_SIZE and SQ_SIZE respectively. The increment logic ensures pointers wrap from `SIZE-1` to `0` rather than advancing to `SIZE`:

```
next = (current + 1 == SIZE) ? 0 : (current + 1)
```

**CQ Full Condition**: The CQ can become full if software does not consume completions fast enough. The full condition is detected when:
```
(CQ_TAIL + 1) mod CQ_SIZE == CQ_HEAD
```

In this state, hardware should stall rather than overwriting unread completions. However, the current implementation does not check for CQ full before writing; it assumes software configures adequate CQ depth and polls frequently enough to prevent overflow.

**Software CQ Management**: Software must advance CQ_HEAD after reading completion entries to make space for new completions. The CQ_HEAD register (offset 0x4C) is writable by software for this purpose. Failure to advance CQ_HEAD will eventually cause hardware to stall when CQ becomes full.

### 5.6.7 Relationship Between SQ and CQ Pointer Updates

The design enforces a strict ordering: SQ_HEAD advances only after the corresponding CQ entry is written. This guarantees that:
- Every completed SQ entry has a corresponding CQ entry in DDR
- Software can determine operation status by reading the CQ
- SQ slot reuse never occurs before completion is reported

The sequence is:
1. SQ descriptor fetched (SQ_HEAD remains unchanged)
2. Operation executed (TX transmission completes)
3. CQ entry written to DDR (CQ_TAIL remains unchanged)
4. Both CQ_TAIL and SQ_HEAD increment atomically

This conservative approach prevents race conditions but does reduce pipelining—the controller must complete the entire operation (fetch, execute, complete) before processing the next descriptor. A more aggressive design might allow SQ_HEAD to advance earlier (e.g., after descriptor fetch) to enable overlapped execution, but this would complicate error handling and completion correlation.

### 5.6.8 Error Status Reporting

The current implementation sets `tx_cpl_status = 0` (success) unconditionally. The tx_streamer does not detect or report errors such as:
- DataMover read failures (invalid address, DDR timeout)
- Fragmentation errors (alignment violations, chunk computation overflow)
- Header inserter errors (FIFO overflow, backpressure timeout)

The CQ entry status field (Word 1, bits [7:0]) is reserved for error codes in future implementations. Potential error codes could include:
- 0x00: Success
- 0x01: Local memory access error (MM2S failure)
- 0x02: Remote memory access error (S2MM failure, not applicable in loopback)
- 0x03: Length mismatch (requested vs. transmitted)
- 0x04: Timeout

To support error reporting, the tx_streamer and DataMover error signals would need to be monitored and propagated through the tx_cpl interface to the controller, which would then populate the status field accordingly.

---

## 5.7 Software Visibility and Completion Polling

The final stage of the RDMA operation cycle involves software detecting completions, reading CQ entries from DDR, and advancing queue pointers to enable continued operation. This section describes the bare-metal software sequence and the cache coherency considerations unique to ARM Cortex-A53 with separate PL fabric.

### 5.7.1 Work Submission Sequence

Software initiates RDMA operations by following a strict sequence that ensures descriptor visibility to hardware and adherence to queue management protocols:

**Step 1: Prepare SQ Descriptor in Memory**  
Software constructs a 64-byte SQ entry in the pre-allocated DDR buffer at address `SQ_BASE + (tail_index × 64)`. The descriptor structure must match the hardware-defined format (8 64-bit words):

```c
volatile sq_entry_t *sq_buf = (volatile sq_entry_t *)SQ_BUFFER_BASE;
uint32_t tail_index = Xil_In32(REG_ADDR(REG_IDX_SQ_TAIL));

// Populate descriptor fields
sq_buf[tail_index].id = 0x12345678;
sq_buf[tail_index].opcode = 0x01;  // WRITE operation
sq_buf[tail_index].flags = 0x0000;
sq_buf[tail_index].local_key = (uint64_t)payload_buffer_address;
sq_buf[tail_index].remote_key = (uint64_t)destination_address;
sq_buf[tail_index].length_lo = payload_size;
sq_buf[tail_index].length_hi = 0;
// reserved fields zeroed
```

**Step 2: Data Cache Flush**  
The ARM Cortex-A53 employs separate L1 data and instruction caches. When software writes to DDR via the cache-coherent path, the descriptor may reside only in cache, not yet visible to PL fabric DMA engines. Explicit cache maintenance is required:

```c
Xil_DCacheFlushRange((UINTPTR)&sq_buf[tail_index], sizeof(sq_entry_t));
```

This operation:
- Forces dirty cache lines covering the descriptor to be written back to DDR
- Ensures PL DataMover reads the latest descriptor content
- Blocks until writeback completes (synchronous operation)

**Step 3: Update SQ_TAIL Pointer (Doorbell Ring)**  
Software signals work availability by advancing the SQ_TAIL pointer. The tail increment must respect circular queue wraparound:

```c
uint32_t new_tail = (tail_index + 1 == SQ_SIZE) ? 0 : (tail_index + 1);
Xil_Out32(REG_ADDR(REG_IDX_SQ_TAIL), new_tail);
```

The write to the SQ_TAIL register (offset 0x30) has dual effects:
- Updates the tail pointer value readable by software
- Generates a single-cycle doorbell pulse to the RDMA controller FSM

The doorbell pulse is a side-effect of the register write; software does not need to take additional action. Alternatively, software may use the explicit SQ_DOORBELL register (offset 0x34) to assert the doorbell without modifying the tail pointer, useful for batch submission scenarios.

**Memory Barrier Considerations**: After the SQ_TAIL write, software should issue a memory barrier (`DMB` or `DSB` instruction on ARM) if subsequent operations depend on the work being initiated. However, for polling-based completion, the barrier is typically not required as the read of CQ_TAIL provides implicit ordering.

### 5.7.2 Completion Detection via Polling

The loopback design does not support interrupts; software must poll the CQ_TAIL register to detect completions. The polling loop continuously reads the read-only CQ_TAIL register and compares it to the software-maintained CQ_HEAD value:

```c
uint32_t cq_head = Xil_In32(REG_ADDR(REG_IDX_CQ_HEAD));
uint32_t cq_tail;

// Poll for CQ_TAIL advancement
do {
    cq_tail = Xil_In32(REG_ADDR(REG_IDX_CQ_TAIL));
} while (cq_tail == cq_head);
```

**Polling Termination**: The loop exits when `CQ_TAIL ≠ CQ_HEAD`, indicating at least one new completion is available. For multiple outstanding operations, the number of available completions is:
```
num_completions = (cq_tail >= cq_head) ? (cq_tail - cq_head) 
                                        : (CQ_SIZE - cq_head + cq_tail);
```

**Timeout Handling**: Production software should implement timeout detection to avoid infinite polling if hardware stalls. Example:
```c
uint32_t timeout = 1000000;  // iterations
while (cq_tail == cq_head && timeout--) {
    cq_tail = Xil_In32(REG_ADDR(REG_IDX_CQ_TAIL));
}
if (timeout == 0) {
    xil_printf("ERROR: Completion timeout\n");
    // Initiate recovery (soft reset, re-init queues)
}
```

### 5.7.3 CQ Entry Read and Cache Invalidation

After detecting CQ_TAIL advancement, software must read the completion entry from DDR at address `CQ_BASE + (cq_head × 32)`. Before reading, software must invalidate the data cache covering the CQ entry:

```c
volatile cq_entry_t *cq_buf = (volatile cq_entry_t *)CQ_BUFFER_BASE;
Xil_DCacheInvalidateRange((UINTPTR)&cq_buf[cq_head], sizeof(cq_entry_t));
```

**Why Cache Invalidation is Required**: 
- The PL DataMover writes CQ entries directly to DDR via the AXI HP port, bypassing the ARM caches
- If software previously read this CQ slot (from a prior operation), stale data may reside in cache
- A cache read without invalidation would return stale cached data rather than the new hardware-written completion
- `Xil_DCacheInvalidateRange()` discards cache lines covering the specified address range, forcing subsequent reads to fetch from DDR

After invalidation, software reads the CQ entry fields:

```c
uint32_t wqe_id = cq_buf[cq_head].wqe_id;
uint32_t status = cq_buf[cq_head].status_opcode & 0xFF;
uint32_t bytes_sent = cq_buf[cq_head].bytes_sent_lo;

xil_printf("Completion for WQE %u: status=0x%02x, bytes=%u\n", 
           wqe_id, status, bytes_sent);
```

**Verifying Operation Success**:
- Check `status == 0` (success)
- Compare `bytes_sent` to requested length to confirm full payload transmission
- Match `wqe_id` to the expected SQ index for correlation

### 5.7.4 CQ_HEAD Advancement

After processing the completion entry, software must advance CQ_HEAD to free the CQ slot for reuse by hardware. The head pointer is writable via the CQ_HEAD register (offset 0x4C):

```c
uint32_t new_cq_head = (cq_head + 1 == CQ_SIZE) ? 0 : (cq_head + 1);
Xil_Out32(REG_ADDR(REG_IDX_CQ_HEAD), new_cq_head);
```

This write informs hardware that software has consumed the completion, making the CQ slot available for future completions. **Failure to advance CQ_HEAD will eventually cause hardware to stall** when the CQ becomes full (when `(CQ_TAIL + 1) mod CQ_SIZE == CQ_HEAD`).

**Batch Processing**: If multiple completions are available (`cq_tail - cq_head > 1`), software may choose to:
1. Process all completions in a loop, advancing CQ_HEAD after each
2. Process all completions, then advance CQ_HEAD once by the total count

The second approach reduces MMIO register writes but delays freeing CQ slots. For low-latency applications, incremental advancement is preferred.

### 5.7.5 SQ_HEAD Observation

Software may optionally read the SQ_HEAD register (offset 0x2C, read-only) to monitor hardware's consumption of SQ descriptors. The SQ_HEAD value indicates the next descriptor hardware will fetch, and observing its advancement confirms that hardware is making forward progress:

```c
uint32_t sq_head = Xil_In32(REG_ADDR(REG_IDX_SQ_HEAD));
xil_printf("Hardware has consumed up to SQ index %u\n", 
           (sq_head == 0) ? (SQ_SIZE - 1) : (sq_head - 1));
```

Since SQ_HEAD advances atomically with CQ_TAIL in the controller, software should observe that:
```
SQ_HEAD == (initial_sq_tail + num_completions) mod SQ_SIZE
```

If SQ_HEAD does not advance after a reasonable timeout, software may infer that hardware has stalled during descriptor fetch or execution, and recovery action (soft reset) may be required.

### 5.7.6 Payload Data Readback and Verification

In the loopback test scenario, software verifies that transmitted payload was correctly received by reading the destination buffer (the "remote" address specified in the SQ descriptor):

```c
volatile uint32_t *dest_buf = (volatile uint32_t *)destination_address;

// Invalidate destination buffer cache lines (written by RX DataMover S2MM)
Xil_DCacheInvalidateRange((UINTPTR)dest_buf, payload_size);

// Compare transmitted and received data
volatile uint32_t *src_buf = (volatile uint32_t *)payload_buffer_address;
for (uint32_t i = 0; i < payload_size / 4; i++) {
    if (dest_buf[i] != src_buf[i]) {
        xil_printf("ERROR: Data mismatch at offset %u: expected 0x%08x, got 0x%08x\n",
                   i * 4, src_buf[i], dest_buf[i]);
    }
}
```

**Critical**: Cache invalidation of the destination buffer is mandatory before reading, as the RX path DataMover S2MM writes directly to DDR, bypassing caches. Without invalidation, software would read stale cache contents rather than the newly written payload.

### 5.7.7 Cache Coherency Summary

The ARM Cortex-A53 + PL fabric architecture requires explicit cache management at software-hardware boundaries:

| **Operation** | **Cache Action** | **Rationale** |
|---------------|------------------|---------------|
| Write SQ descriptor | `Xil_DCacheFlushRange(SQ_entry)` | Ensure PL sees latest descriptor |
| Write payload buffer | `Xil_DCacheFlushRange(payload)` | Ensure TX DataMover reads correct data |
| Read CQ entry | `Xil_DCacheInvalidateRange(CQ_entry)` | Discard stale cache, read PL-written completion |
| Read RX payload | `Xil_DCacheInvalidateRange(dest_buf)` | Discard stale cache, read PL-written payload |

**Flush vs. Invalidate**:
- **Flush**: Write dirty cache lines to DDR, making CPU writes visible to PL
- **Invalidate**: Discard cache lines, forcing subsequent reads to fetch from DDR, making PL writes visible to CPU

Incorrect cache management will manifest as:
- Hardware reading stale descriptor data (flush missing before SQ_TAIL write)
- Software reading stale completion data (invalidate missing before CQ entry read)
- Data corruption in payload verification (invalidate missing on destination buffer)

### 5.7.8 Multi-Operation Pipelining

Software may post multiple SQ descriptors before polling for completions, achieving pipelined operation:

```c
// Submit multiple operations
for (uint32_t i = 0; i < batch_size; i++) {
    // Prepare descriptor at SQ_TAIL
    // Flush cache
    // Advance SQ_TAIL
}

// Poll for all completions
uint32_t initial_cq_head = cq_head;
while ((cq_head - initial_cq_head) < batch_size) {
    cq_tail = Xil_In32(REG_ADDR(REG_IDX_CQ_TAIL));
    // Process available completions
    // Advance CQ_HEAD
    cq_head = Xil_In32(REG_ADDR(REG_IDX_CQ_HEAD));
}
```

**Pipelining Limits**: The maximum number of in-flight operations is limited by:
```
max_in_flight = min(SQ_SIZE - 1, CQ_SIZE - 1)
```

Subtracting 1 accounts for the queue full condition (tail cannot equal head in a full queue). Posting more work than this limit will cause SQ to become full, requiring software to wait for SQ_HEAD advancement before posting additional descriptors.

The controller's single-threaded FSM processes one descriptor at a time, so pipelining benefits come from overlapping software submission with hardware execution, not from parallel execution of multiple operations by hardware.

### 5.7.9 Error Recovery and Reset

If hardware fails to make forward progress (SQ_HEAD or CQ_TAIL does not advance within expected timeout), software recovery options are limited in this proof-of-concept design.

**System-Level Reset**: The most reliable recovery mechanism is a full system reset via the Zynq PS reset controller or power cycle. This restarts all PL logic including the RDMA controller, DataMover IP, and queue state machines.

**Queue Pointer Reinitialization**: After system reset, software must reinitialize all queue configuration:

```c
// Assume hardware reset has occurred (PS reboot, PL reconfiguration, etc.)

// Reinitialize queue base addresses and sizes
Xil_Out32(REG_ADDR(REG_IDX_SQ_BASE_LO), SQ_BUFFER_BASE & 0xFFFFFFFF);
Xil_Out32(REG_ADDR(REG_IDX_SQ_BASE_HI), (SQ_BUFFER_BASE >> 32) & 0xFFFFFFFF);
Xil_Out32(REG_ADDR(REG_IDX_SQ_SIZE), SQ_SIZE);
Xil_Out32(REG_ADDR(REG_IDX_SQ_TAIL), 0);

Xil_Out32(REG_ADDR(REG_IDX_CQ_BASE_LO), CQ_BUFFER_BASE & 0xFFFFFFFF);
Xil_Out32(REG_ADDR(REG_IDX_CQ_BASE_HI), (CQ_BUFFER_BASE >> 32) & 0xFFFFFFFF);
Xil_Out32(REG_ADDR(REG_IDX_CQ_SIZE), CQ_SIZE);
Xil_Out32(REG_ADDR(REG_IDX_CQ_HEAD), 0);

// Hardware-owned pointers (SQ_HEAD, CQ_TAIL) reset to zero internally
```

After reinitialization, all queue pointers return to zero, and any in-flight operations are lost. Software must clear descriptor and completion buffers in DDR and re-submit work from a known good state.

**CONTROL Register**: The CONTROL register (offset 0x00) exists in the register map with fields for enable and reset, but a software-controlled reset/recovery sequence using these bits is not demonstrated in the provided test code (`main.c`). The register interface defines these bits, but their functional behavior in terms of selective reset (controller-only vs. full PL reset) and required reset duration is not documented. Software should rely on system-level reset mechanisms for reliable recovery.

**Not specified in provided code**: The exact behavior of CONTROL register reset/enable bits, whether they provide selective reset of the controller FSM without affecting DataMover state, required reset hold time, and whether writes to read-only pointer registers trigger any internal state changes. The test software does not demonstrate a soft reset sequence, suggesting this feature may not be fully implemented or validated.

