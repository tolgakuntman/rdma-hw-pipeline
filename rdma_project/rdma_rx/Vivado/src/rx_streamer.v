`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Module: rx_streamer
// 
// Description:
//   Receive engine that orchestrates RDMA WRITE packet reception
//   - Receives packets from network via rx_header_parser
//   - Extracts RDMA WRITE operation details from parsed header
//   - Issues S2MM commands to Data Mover to write payload to DDR
//   - Operates independently without rdma_controller coordination
//
// Operation:
//   - Waits for header_valid pulse from rx_header_parser
//   - Checks if opcode indicates WRITE operation
//   - Programs Data Mover S2MM with destination address and length
//   - Waits for write completion
//   - Returns to idle for next packet
//
// FSM States:
//   IDLE           - Wait for incoming packet header
//   CHECK_OPCODE   - Verify this is a WRITE operation
//   ISSUE_DM_CMD   - Send S2MM command to Data Mover
//   WAIT_COMPLETE  - Wait for Data Mover write completion
//
////////////////////////////////////////////////////////////////////////////////

module rx_streamer #(
    // Data Mover Parameters
    parameter C_ADDR_WIDTH       = 32,          // DDR address width
    parameter C_DATA_WIDTH       = 32,          // AXI-Stream data width
    parameter C_BTT_WIDTH        = 23,          // Bytes to transfer width (up to 8MB)
    
    // RDMA Parameters
    parameter RDMA_OPCODE_WIDTH  = 8,
    parameter RDMA_ADDR_WIDTH    = 64,
    parameter RDMA_RKEY_WIDTH    = 32,
    parameter RDMA_LENGTH_WIDTH  = 32,
    parameter OFFSET_LENGTH       = 16,          // Fragment offset length in bits  
    // RDMA Opcode definitions (matching your test opcode)
    parameter RDMA_OPCODE_WRITE_FIRST   = 8'h06,
    parameter RDMA_OPCODE_WRITE_MIDDLE  = 8'h07,
    parameter RDMA_OPCODE_WRITE_LAST    = 8'h08,
    parameter RDMA_OPCODE_WRITE_ONLY    = 8'h0A,
    parameter RDMA_OPCODE_WRITE_TEST    = 8'h01  // Test opcode from main.c
) (
    // Clock and Reset
    input  wire                             aclk,
    input  wire                             aresetn,

    // Header Parser Interface
    input  wire                             header_valid,          // Pulse when header parsed
    input  wire [RDMA_OPCODE_WIDTH-1:0]    rdma_opcode,          // RDMA operation code
    input  wire [RDMA_ADDR_WIDTH-1:0]      rdma_remote_addr,     // Destination address (local for writes)
    input  wire [RDMA_RKEY_WIDTH-1:0]      rdma_rkey,            // Remote key (for validation)
    input  wire [RDMA_LENGTH_WIDTH-1:0]    rdma_length,          // Payload length
    input wire [OFFSET_LENGTH-1:0]          fragment_offset,      // Fragment offset
    // Data Mover S2MM Command Interface (AXI-Stream)
    output wire [71:0]                      m_axis_s2mm_cmd_tdata,
    output wire                             m_axis_s2mm_cmd_tvalid,
    input  wire                             m_axis_s2mm_cmd_tready,
    
    // Data Mover S2MM Status Interface
    input  wire                             s2mm_wr_xfer_cmplt,
    
    // Status outputs
    output wire [2:0]                       rx_state,
    output wire                             rx_active,            // Currently processing a write
    output wire                             write_accepted,       // Valid WRITE command accepted (pulse)
    output wire                             write_complete        // Write operation completed (pulse)
);

    localparam [2:0] STATE_IDLE          = 3'd0;
    localparam [2:0] STATE_CHECK_OPCODE  = 3'd1;
    localparam [2:0] STATE_PREPARE_CMD   = 3'd2;
    localparam [2:0] STATE_ISSUE_DM_CMD  = 3'd3;
    localparam [2:0] STATE_WAIT_COMPLETE = 3'd4;
    
    reg [2:0] state_reg, state_next;
    
    // Latched header fields - captured immediately when header_valid pulses
    reg [RDMA_OPCODE_WIDTH-1:0]    opcode_reg;
    reg [C_ADDR_WIDTH-1:0]         dest_addr_reg;
    reg [RDMA_LENGTH_WIDTH-1:0]    length_reg;
    reg [RDMA_RKEY_WIDTH-1:0]      rkey_reg;
    reg [OFFSET_LENGTH-1:0]      fragment_offset_reg;
    // Flag to indicate new header is available
    reg                             header_pending;
    
    // Data Mover command registers
    reg [C_ADDR_WIDTH-1:0]         s2mm_addr_reg;
    reg [C_BTT_WIDTH-1:0]          s2mm_btt_reg;
    
    // Status signals
    reg                             write_accepted_reg;
    reg                             write_complete_reg;
    
    // Check if opcode is a WRITE variant
    wire is_write_op = (opcode_reg == RDMA_OPCODE_WRITE_FIRST)  ||
                       (opcode_reg == RDMA_OPCODE_WRITE_MIDDLE) ||
                       (opcode_reg == RDMA_OPCODE_WRITE_LAST)   ||
                       (opcode_reg == RDMA_OPCODE_WRITE_ONLY)   ||
                       (opcode_reg == RDMA_OPCODE_WRITE_TEST);  // Accept test opcode 0x01
    
    // Output assignments
    assign rx_state = state_reg;
    assign rx_active = (state_reg != STATE_IDLE);
    assign write_accepted = write_accepted_reg;
    assign write_complete = write_complete_reg;
    
    // Data Mover S2MM command interface (72-bit AXI-Stream format)
    // Format: [Reserved(8) | Address(32) | Type(1) | DSA(1) | Reserved(6) | EOF(1) | BTT(23)]
    assign m_axis_s2mm_cmd_tdata  = {8'b00000000, s2mm_addr_reg, 1'b0, 1'b1, 6'b000000, 1'b1, s2mm_btt_reg[22:0]};
    assign m_axis_s2mm_cmd_tvalid = (state_reg == STATE_ISSUE_DM_CMD) ? 1'b1 : 1'b0;
    
    // State register
    always @(posedge aclk) begin
        if (!aresetn) begin
            state_reg <= STATE_IDLE;
        end else begin
            state_reg <= state_next;
        end
    end
    
    // Latch header fields immediately when header_valid pulses (regardless of state)
    // This ensures we capture every header, even if FSM is still processing previous packet
    always @(posedge aclk) begin
        if (!aresetn) begin
            opcode_reg          <= 0;
            dest_addr_reg       <= 0;
            length_reg          <= 0;
            rkey_reg            <= 0;
            fragment_offset_reg <= 0;
            header_pending      <= 0;
        end else begin
            // Capture header fields whenever header_valid pulses
            if (header_valid) begin
                opcode_reg    <= rdma_opcode;
                dest_addr_reg <= rdma_remote_addr[C_ADDR_WIDTH-1:0];  // Use lower bits as local address
                length_reg    <= rdma_length;
                rkey_reg      <= rdma_rkey;
                header_pending <= 1;  // Mark that new header is available
                fragment_offset_reg <= fragment_offset;
            end
            // Clear pending flag when FSM starts processing (enters CHECK_OPCODE)
            else if (state_reg == STATE_CHECK_OPCODE) begin
                header_pending <= 0;
            end
        end
    end
    
    // S2MM command generation
    always @(posedge aclk) begin
        if (!aresetn) begin
            s2mm_addr_reg  <= 0;
            s2mm_btt_reg   <= 0;
        end else begin
            // Prepare command in PREPARE_CMD state
            if (state_reg == STATE_PREPARE_CMD) begin
                s2mm_addr_reg  <= dest_addr_reg + fragment_offset_reg;  // Add fragment offset to base address
                s2mm_btt_reg   <= length_reg[C_BTT_WIDTH-1:0];
            end
        end
    end
    
    // FSM combinational logic
    always @(*) begin
        // Default assignments
        state_next = state_reg;
        
        write_accepted_reg = 0;
        write_complete_reg = 0;
        
        case (state_reg)
            STATE_IDLE: begin
                // Wait for header_pending flag (set when header_valid pulses)
                if (header_pending) begin
                    state_next = STATE_CHECK_OPCODE;
                end
            end
            
            STATE_CHECK_OPCODE: begin
                if (is_write_op) begin
                    // Valid WRITE operation detected
                    write_accepted_reg = 1;
                    state_next = STATE_PREPARE_CMD;
                end else begin
                    // Not a WRITE operation, ignore and return to idle
                    state_next = STATE_IDLE;
                end
            end
            
            STATE_PREPARE_CMD: begin
                // Prepare S2MM command (addr and btt loaded in this cycle)
                state_next = STATE_ISSUE_DM_CMD;
            end
            
            STATE_ISSUE_DM_CMD: begin
                // Hold in this state until command is accepted
                if (m_axis_s2mm_cmd_tready) begin
                    // Command accepted by Data Mover
                    state_next = STATE_WAIT_COMPLETE;
                end
            end
            
            STATE_WAIT_COMPLETE: begin
                if (s2mm_wr_xfer_cmplt) begin
                    // Write completed successfully
                    write_complete_reg = 1;
                    state_next = STATE_IDLE;
                end
            end
            
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end

endmodule
