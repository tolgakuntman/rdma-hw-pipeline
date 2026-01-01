`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Module: tx_streamer
// 
// Description:
//   Send engine that orchestrates RDMA packet transmission with fragmentation
//   - Accepts send commands from rdma_controller (SQ index, addr, len, flags)
//   - Fragments large payloads respecting block size and 4KB boundaries
//   - Programs tx_header_inserter with RDMA metadata
//   - Issues MM2S commands to Data Mover for payload streaming
//   - Returns completion status to controller when all fragments sent
//
// Fragmentation Logic:
//   - Clamps each chunk to configured block size (e.g., 4096 bytes)
//   - Respects 4KB address alignment for AXI Data Mover
//   - Tracks fragment ID and offset for multi-fragment messages
//   - Ensures sequential transmission of all fragments
//
// FSM States:
//   IDLE           - Wait for send command from controller
//   INIT_FRAGMENT  - Initialize counters for new fragment
//   PROGRAM_HEADER - Configure header inserter with RDMA metadata
//   START_HEADER   - Pulse start_tx to header inserter
//   ISSUE_DM_CMD   - Send MM2S command to Data Mover
//   WAIT_COMPLETE  - Wait for Data Mover and header inserter completion
//   UPDATE_STATE   - Advance counters, check if more fragments needed
//   SEND_CPL       - Return completion to controller
//
////////////////////////////////////////////////////////////////////////////////

module tx_streamer #(
    // Data Mover Parameters
    parameter C_ADDR_WIDTH       = 32,          // DDR address width
    parameter C_DATA_WIDTH       = 32,          // AXI-Stream data width
    parameter C_BTT_WIDTH        = 23,          // Bytes to transfer width (up to 8MB)
    
    // Fragmentation Parameters
    parameter BLOCK_SIZE         = 4096,        // Max bytes per fragment (4KB default)
    parameter BOUNDARY_4KB       = 4096,        // 4KB boundary for address alignment
    
    // RDMA Parameters
    parameter SQ_INDEX_WIDTH     = 8,           // Send Queue index width
    parameter RDMA_OPCODE_WIDTH  = 8,
    parameter RDMA_PSN_WIDTH     = 24,
    parameter RDMA_QPN_WIDTH     = 24,
    parameter RDMA_ADDR_WIDTH    = 64,
    parameter RDMA_RKEY_WIDTH    = 32,
    parameter RDMA_LENGTH_WIDTH  = 32
) (
    // Clock and Reset
    input  wire                             aclk,
    input  wire                             aresetn,

    input  wire                             tx_cmd_valid,
    output wire                             tx_cmd_ready,
    input  wire [SQ_INDEX_WIDTH-1:0]       tx_cmd_sq_index,      // Send Queue index
    input  wire [C_ADDR_WIDTH-1:0]         tx_cmd_ddr_addr,      // DDR payload address
    input  wire [RDMA_LENGTH_WIDTH-1:0]    tx_cmd_length,        // Total payload length
    input  wire [RDMA_OPCODE_WIDTH-1:0]    tx_cmd_opcode,        // RDMA opcode
    input  wire [RDMA_QPN_WIDTH-1:0]       tx_cmd_dest_qp,       // Destination QP
    input  wire [RDMA_ADDR_WIDTH-1:0]      tx_cmd_remote_addr,   // Remote virtual address
    input  wire [RDMA_RKEY_WIDTH-1:0]      tx_cmd_rkey,          // Remote key
    input  wire [15:0]                      tx_cmd_partition_key, // Partition key
    input  wire [7:0]                       tx_cmd_service_level, // Service level
    input  wire [RDMA_PSN_WIDTH-1:0]       tx_cmd_psn,           // Starting PSN
    
    output wire                             tx_cpl_valid,
    input  wire                             tx_cpl_ready,
    output wire [SQ_INDEX_WIDTH-1:0]       tx_cpl_sq_index,      // Original SQ index
    output wire [7:0]                       tx_cpl_status,        // 0=success, non-zero=error
    output wire [RDMA_LENGTH_WIDTH-1:0]    tx_cpl_bytes_sent,    // Total bytes transmitted
    
    output wire                             hdr_start_tx,
    input  wire                             hdr_tx_busy,
    input  wire                             hdr_tx_done,
    output wire [RDMA_OPCODE_WIDTH-1:0]    hdr_rdma_opcode,
    output wire [RDMA_PSN_WIDTH-1:0]       hdr_rdma_psn,
    output wire [RDMA_QPN_WIDTH-1:0]       hdr_rdma_dest_qp,
    output wire [RDMA_ADDR_WIDTH-1:0]      hdr_rdma_remote_addr,
    output wire [RDMA_RKEY_WIDTH-1:0]      hdr_rdma_rkey,
    output wire [RDMA_LENGTH_WIDTH-1:0]    hdr_rdma_length,
    output wire [15:0]                      hdr_rdma_partition_key,
    output wire [7:0]                       hdr_rdma_service_level,
    output wire [15:0]                      hdr_fragment_id,
    output wire                             hdr_more_fragments,
    output wire [15:0]                      hdr_fragment_offset,
    
    // Data Mover MM2S Command Interface (AXI-Stream)
    output wire [71:0]                      m_axis_mm2s_cmd_tdata,
    output wire                             m_axis_mm2s_cmd_tvalid,
    input  wire                             m_axis_mm2s_cmd_tready,
    
    // Data Mover MM2S Status Interface
    input  wire                             mm2s_rd_xfer_cmplt,
    output wire [3:0]                       streamer_state
);

    localparam [3:0] STATE_IDLE           = 4'd0;
    localparam [3:0] STATE_INIT_FRAGMENT  = 4'd1;
    localparam [3:0] STATE_PROGRAM_HEADER = 4'd2;
    localparam [3:0] STATE_START_HEADER   = 4'd3;
    localparam [3:0] STATE_ISSUE_DM_CMD   = 4'd4;
    localparam [3:0] STATE_WAIT_DM_STS    = 4'd5;
    localparam [3:0] STATE_WAIT_HDR_DONE  = 4'd6;
    localparam [3:0] STATE_UPDATE_STATE   = 4'd7;
    localparam [3:0] STATE_SEND_CPL       = 4'd8;
    
    reg [3:0] state_reg, state_next;
    
    reg [SQ_INDEX_WIDTH-1:0]       cmd_sq_index_reg;
    reg [C_ADDR_WIDTH-1:0]         cmd_ddr_addr_reg;
    reg [RDMA_LENGTH_WIDTH-1:0]    cmd_length_reg;
    reg [RDMA_OPCODE_WIDTH-1:0]    cmd_opcode_reg;
    reg [RDMA_QPN_WIDTH-1:0]       cmd_dest_qp_reg;
    reg [RDMA_ADDR_WIDTH-1:0]      cmd_remote_addr_reg;
    reg [RDMA_RKEY_WIDTH-1:0]      cmd_rkey_reg;
    reg [15:0]                      cmd_partition_key_reg;
    reg [7:0]                       cmd_service_level_reg;
    reg [RDMA_PSN_WIDTH-1:0]       cmd_psn_reg;
    
    reg [RDMA_LENGTH_WIDTH-1:0]    remaining_len_reg;
    reg [C_ADDR_WIDTH-1:0]         current_addr_reg;
    reg [RDMA_ADDR_WIDTH-1:0]      current_remote_addr_reg;
    reg [15:0]                      frag_idx_reg;
    reg [15:0]                      frag_offset_reg;
    reg [RDMA_LENGTH_WIDTH-1:0]    chunk_len_reg;
    reg [RDMA_LENGTH_WIDTH-1:0]    total_sent_reg;
    reg [7:0]                       error_status_reg;
    
    reg [RDMA_OPCODE_WIDTH-1:0]    hdr_opcode_reg;
    reg [RDMA_PSN_WIDTH-1:0]       hdr_psn_reg;
    reg [RDMA_QPN_WIDTH-1:0]       hdr_dest_qp_reg;
    reg [RDMA_ADDR_WIDTH-1:0]      hdr_remote_addr_reg;
    reg [RDMA_RKEY_WIDTH-1:0]      hdr_rkey_reg;
    reg [RDMA_LENGTH_WIDTH-1:0]    hdr_length_reg;
    reg [15:0]                      hdr_partition_key_reg;
    reg [7:0]                       hdr_service_level_reg;
    reg [15:0]                      hdr_frag_id_reg;
    reg                             hdr_more_frags_reg;
    reg [15:0]                      hdr_frag_offset_reg;
    reg                             hdr_start_tx_reg;
    
    reg [C_ADDR_WIDTH-1:0]         mm2s_addr_reg;
    reg [C_BTT_WIDTH-1:0]          mm2s_btt_reg;
    reg                             mm2s_valid_reg;
    
    reg                             tx_cpl_valid_reg;
    reg [SQ_INDEX_WIDTH-1:0]       tx_cpl_sq_index_reg;
    reg [7:0]                       tx_cpl_status_reg;
    reg [RDMA_LENGTH_WIDTH-1:0]    tx_cpl_bytes_sent_reg;
    
    wire [RDMA_LENGTH_WIDTH-1:0]   chunk_to_boundary;
    wire [RDMA_LENGTH_WIDTH-1:0]   chunk_by_block;
    wire [RDMA_LENGTH_WIDTH-1:0]   chunk_len_next;
    wire                            more_fragments;
    
    // For first fragment calculation (using command inputs)
    wire [RDMA_LENGTH_WIDTH-1:0]   first_chunk_to_boundary;
    wire [RDMA_LENGTH_WIDTH-1:0]   first_chunk_by_block;
    wire [RDMA_LENGTH_WIDTH-1:0]   first_chunk_len;
    
    // Calculate bytes remaining to next 4KB boundary (for current fragment)
    assign chunk_to_boundary = BOUNDARY_4KB - (current_addr_reg & (BOUNDARY_4KB - 1));
    
    // Clamp to block size (for current fragment)
    assign chunk_by_block = (remaining_len_reg > BLOCK_SIZE) ? BLOCK_SIZE : remaining_len_reg;
    
    // Final chunk size: minimum of (remaining, block_size, to_boundary) (for current fragment)
    assign chunk_len_next = (chunk_by_block < chunk_to_boundary) ? chunk_by_block : chunk_to_boundary;
    
    // Calculate first fragment size using command inputs
    assign first_chunk_to_boundary = BOUNDARY_4KB - (cmd_ddr_addr_reg & (BOUNDARY_4KB - 1));
    assign first_chunk_by_block = (cmd_length_reg > BLOCK_SIZE) ? BLOCK_SIZE : cmd_length_reg;
    assign first_chunk_len = (first_chunk_by_block < first_chunk_to_boundary) ? first_chunk_by_block : first_chunk_to_boundary;
    
    // Check if more fragments will be needed after this one
    assign more_fragments = (remaining_len_reg > chunk_len_reg);
    
    // Command interface
    assign tx_cmd_ready = (state_reg == STATE_IDLE);
    assign streamer_state =state_reg;
    // Completion interface
    assign tx_cpl_valid        = tx_cpl_valid_reg;
    assign tx_cpl_sq_index     = tx_cpl_sq_index_reg;
    assign tx_cpl_status       = tx_cpl_status_reg;
    assign tx_cpl_bytes_sent   = tx_cpl_bytes_sent_reg;
    
    // Header inserter interface
    assign hdr_start_tx            = hdr_start_tx_reg;
    assign hdr_rdma_opcode         = hdr_opcode_reg;
    assign hdr_rdma_psn            = hdr_psn_reg;
    assign hdr_rdma_dest_qp        = hdr_dest_qp_reg;
    assign hdr_rdma_remote_addr    = hdr_remote_addr_reg;
    assign hdr_rdma_rkey           = hdr_rkey_reg;
    assign hdr_rdma_length         = hdr_length_reg;
    assign hdr_rdma_partition_key  = hdr_partition_key_reg;
    assign hdr_rdma_service_level  = hdr_service_level_reg;
    assign hdr_fragment_id         = hdr_frag_id_reg;
    assign hdr_more_fragments      = hdr_more_frags_reg;
    assign hdr_fragment_offset     = hdr_frag_offset_reg;
    
    // Data Mover MM2S command interface (72-bit AXI-Stream format)
    // Format: [Reserved(8) | Address(32) | Type(1) | DSA(1) | Reserved(6) | EOF(1) | BTT(23)]
    assign m_axis_mm2s_cmd_tdata = {8'b00000000, mm2s_addr_reg, 1'b0, 1'b1, 6'b000000, 1'b1, mm2s_btt_reg[22:0]};
    assign m_axis_mm2s_cmd_tvalid = mm2s_valid_reg;
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            state_reg <= STATE_IDLE;
        end else begin
            state_reg <= state_next;
        end
    end
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            cmd_sq_index_reg       <= 0;
            cmd_ddr_addr_reg       <= 0;
            cmd_length_reg         <= 0;
            cmd_opcode_reg         <= 0;
            cmd_dest_qp_reg        <= 0;
            cmd_remote_addr_reg    <= 0;
            cmd_rkey_reg           <= 0;
            cmd_partition_key_reg  <= 0;
            cmd_service_level_reg  <= 0;
            cmd_psn_reg            <= 0;
        end else if (tx_cmd_valid && tx_cmd_ready) begin
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
        end
    end
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            remaining_len_reg       <= 0;
            current_addr_reg        <= 0;
            current_remote_addr_reg <= 0;
            frag_idx_reg            <= 0;
            frag_offset_reg         <= 0;
            chunk_len_reg           <= 0;
            total_sent_reg          <= 0;
            error_status_reg        <= 0;
        end else begin
            case (state_reg)
                STATE_INIT_FRAGMENT: begin
                    // Initialize for new send operation
                    remaining_len_reg       <= cmd_length_reg;
                    current_addr_reg        <= cmd_ddr_addr_reg;
                    current_remote_addr_reg <= cmd_remote_addr_reg;
                    frag_idx_reg            <= 0;
                    frag_offset_reg         <= 0;
                    chunk_len_reg           <= first_chunk_len;  // Use first_chunk_len for initial fragment
                    total_sent_reg          <= 0;
                    error_status_reg        <= 0;
                end
                
                STATE_UPDATE_STATE: begin
                    // Advance counters for next fragment
                    remaining_len_reg       <= remaining_len_reg - chunk_len_reg;
                    current_addr_reg        <= current_addr_reg + chunk_len_reg;
                    current_remote_addr_reg <= current_remote_addr_reg + chunk_len_reg;
                    frag_idx_reg            <= frag_idx_reg + 1;
                    frag_offset_reg         <= frag_offset_reg + chunk_len_reg[15:0];
                    total_sent_reg          <= total_sent_reg + chunk_len_reg;
                    
                    // Calculate next chunk length
                    if (remaining_len_reg > chunk_len_reg) begin
                        chunk_len_reg <= chunk_len_next;
                    end
                end
            endcase
        end
    end
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            hdr_opcode_reg         <= 0;
            hdr_psn_reg            <= 0;
            hdr_dest_qp_reg        <= 0;
            hdr_remote_addr_reg    <= 0;
            hdr_rkey_reg           <= 0;
            hdr_length_reg         <= 0;
            hdr_partition_key_reg  <= 0;
            hdr_service_level_reg  <= 0;
            hdr_frag_id_reg        <= 0;
            hdr_more_frags_reg     <= 0;
            hdr_frag_offset_reg    <= 0;
        end else if (state_reg == STATE_PROGRAM_HEADER) begin
            hdr_opcode_reg         <= cmd_opcode_reg;
            hdr_psn_reg            <= cmd_psn_reg;
            hdr_dest_qp_reg        <= cmd_dest_qp_reg;
            hdr_remote_addr_reg    <= current_remote_addr_reg;
            hdr_rkey_reg           <= cmd_rkey_reg;
            hdr_length_reg         <= chunk_len_reg;
            hdr_partition_key_reg  <= cmd_partition_key_reg;
            hdr_service_level_reg  <= cmd_service_level_reg;
            hdr_frag_id_reg        <= frag_idx_reg;
            hdr_more_frags_reg     <= more_fragments;
            hdr_frag_offset_reg    <= frag_offset_reg;
        end
    end
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            mm2s_addr_reg <= 0;
            mm2s_btt_reg <= 0;
            mm2s_valid_reg <= 0;
        end else begin
            mm2s_valid_reg <= 0; // Default: clear valid
            
            if (state_reg == STATE_ISSUE_DM_CMD) begin
                mm2s_addr_reg <= current_addr_reg;
                mm2s_btt_reg <= chunk_len_reg[C_BTT_WIDTH-1:0];
                mm2s_valid_reg <= 1;
            end
        end
    end
    
    always @(*) begin
        // Default assignments
        state_next = state_reg;
        
        hdr_start_tx_reg = 0;
        
        tx_cpl_valid_reg      = 0;
        tx_cpl_sq_index_reg   = cmd_sq_index_reg;
        tx_cpl_status_reg     = error_status_reg;
        tx_cpl_bytes_sent_reg = total_sent_reg;
        
        case (state_reg)
            STATE_IDLE: begin
                if (tx_cmd_valid) begin
                    state_next = STATE_INIT_FRAGMENT;
                end
            end
            
            STATE_INIT_FRAGMENT: begin
                state_next = STATE_PROGRAM_HEADER;
            end
            
            STATE_PROGRAM_HEADER: begin
                // Wait for header inserter to be idle
                if (!hdr_tx_busy) begin
                    state_next = STATE_START_HEADER;
                end
            end
            
            STATE_START_HEADER: begin
                hdr_start_tx_reg = 1;
                state_next = STATE_ISSUE_DM_CMD;
            end
            
            STATE_ISSUE_DM_CMD: begin
                if (m_axis_mm2s_cmd_tready) begin
                    state_next = STATE_WAIT_DM_STS;
                end
            end
            
            STATE_WAIT_DM_STS: begin
                if (mm2s_rd_xfer_cmplt) begin
                    state_next = STATE_WAIT_HDR_DONE;
                end
            end
            
            STATE_WAIT_HDR_DONE: begin
                if (hdr_tx_done) begin
                    state_next = STATE_UPDATE_STATE;
                end
            end
            
            STATE_UPDATE_STATE: begin
                if (remaining_len_reg > chunk_len_reg) begin
                    // More fragments to send
                    state_next = STATE_PROGRAM_HEADER;
                end else begin
                    // All fragments sent, send completion
                    state_next = STATE_SEND_CPL;
                end
            end
            
            STATE_SEND_CPL: begin
                tx_cpl_valid_reg = 1;
                
                if (tx_cpl_ready) begin
                    state_next = STATE_IDLE;
                end
            end
            
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end

endmodule
