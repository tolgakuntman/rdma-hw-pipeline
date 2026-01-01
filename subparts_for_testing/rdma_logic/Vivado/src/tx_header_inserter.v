`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Module: tx_header_inserter
// 
// Description:
//   Inserts RDMA header before streaming data payload
//   - Receives data from data mover (AXI-Stream slave)
//   - Receives RDMA header metadata via control wires
//   - Outputs RDMA header followed by data payload (AXI-Stream master)
//
// FSM States:
//   IDLE        - Wait for start signal and valid header metadata
//   SEND_HEADER - Stream RDMA header fields to master
//   SEND_DATA   - Pass-through data from slave to master
//
////////////////////////////////////////////////////////////////////////////////

module tx_header_inserter #(
    // AXI-Stream Parameters
    parameter C_AXIS_TDATA_WIDTH = 32,         // Data width in bits
    parameter C_AXIS_TKEEP_WIDTH = 4,          // Keep width (TDATA_WIDTH/8)
    
    // RDMA Header Parameters (typical RDMA over Ethernet)
    parameter RDMA_OPCODE_WIDTH  = 8,          // RDMA opcode
    parameter RDMA_PSN_WIDTH     = 24,         // Packet Sequence Number
    parameter RDMA_QPN_WIDTH     = 24,         // Queue Pair Number
    parameter RDMA_ADDR_WIDTH    = 64,         // Remote virtual address
    parameter RDMA_RKEY_WIDTH    = 32,         // Remote key
    parameter RDMA_LENGTH_WIDTH  = 32          // DMA length
) (
    input  wire                             aclk,
    input  wire                             aresetn,

    input  wire [C_AXIS_TDATA_WIDTH-1:0]   s_axis_tdata,
    input  wire [C_AXIS_TKEEP_WIDTH-1:0]   s_axis_tkeep,
    input  wire                             s_axis_tvalid,
    output wire                             s_axis_tready,
    input  wire                             s_axis_tlast,
    
    output wire [C_AXIS_TDATA_WIDTH-1:0]   m_axis_tdata,
    output wire [C_AXIS_TKEEP_WIDTH-1:0]   m_axis_tkeep,
    output wire                             m_axis_tvalid,
    input  wire                             m_axis_tready,
    output wire                             m_axis_tlast,
    
    input  wire                             start_tx,              // Pulse to start transmission
    output wire                             tx_busy,               // Transmission in progress
    output wire                             tx_done,               // Transmission complete
    
    // RDMA Header Fields
    input  wire [RDMA_OPCODE_WIDTH-1:0]    rdma_opcode,          // RDMA operation code
    input  wire [RDMA_PSN_WIDTH-1:0]       rdma_psn,             // Packet Sequence Number
    input  wire [RDMA_QPN_WIDTH-1:0]       rdma_dest_qp,         // Destination Queue Pair
    input  wire [RDMA_ADDR_WIDTH-1:0]      rdma_remote_addr,     // Remote virtual address
    input  wire [RDMA_RKEY_WIDTH-1:0]      rdma_rkey,            // Remote key for RDMA
    input  wire [RDMA_LENGTH_WIDTH-1:0]    rdma_length,          // Payload length
    
    // Optional: Additional header fields
    input  wire [15:0]                      rdma_partition_key,   // Partition key
    input  wire [7:0]                       rdma_service_level,   // Service level
    
    // Future: Fragmentation support signals (reserved for future use)
    input  wire [15:0]                      fragment_id,          // Fragment identifier
    input  wire                             more_fragments,       // More fragments flag
    input  wire [15:0]                      fragment_offset       // Fragment offset
);

    localparam [1:0] STATE_IDLE        = 2'b00;
    localparam [1:0] STATE_SEND_HEADER = 2'b01;
    localparam [1:0] STATE_SEND_DATA   = 2'b10;
    
    reg [1:0] state_reg, state_next;
    
    // Header counter - tracks which portion of header is being sent
    // Assuming header fits in multiple beats depending on data width
    reg [3:0] header_beat_count_reg, header_beat_count_next;
    
    // Latched header metadata (capture at start_tx)
    reg [RDMA_OPCODE_WIDTH-1:0]    rdma_opcode_reg;
    reg [RDMA_PSN_WIDTH-1:0]       rdma_psn_reg;
    reg [RDMA_QPN_WIDTH-1:0]       rdma_dest_qp_reg;
    reg [RDMA_ADDR_WIDTH-1:0]      rdma_remote_addr_reg;
    reg [RDMA_RKEY_WIDTH-1:0]      rdma_rkey_reg;
    reg [RDMA_LENGTH_WIDTH-1:0]    rdma_length_reg;
    reg [15:0]                      rdma_partition_key_reg;
    reg [7:0]                       rdma_service_level_reg;
    
    // Future fragmentation registers (reserved)
    reg [15:0]                      fragment_id_reg;
    reg                             more_fragments_reg;
    reg [15:0]                      fragment_offset_reg;
    
    // Master output registers
    reg [C_AXIS_TDATA_WIDTH-1:0]   m_axis_tdata_reg;
    reg [C_AXIS_TKEEP_WIDTH-1:0]   m_axis_tkeep_reg;
    reg                             m_axis_tvalid_reg;
    reg                             m_axis_tlast_reg;
    
    // Slave ready signal
    reg                             s_axis_tready_reg;
    
    // Status signals
    reg                             tx_busy_reg;
    reg                             tx_done_reg;
    
    localparam HEADER_SIZE_BITS = 208;
    localparam HEADER_BEATS = 7;  // Fixed for 32-bit bus
    
    assign m_axis_tdata  = m_axis_tdata_reg;
    assign m_axis_tkeep  = m_axis_tkeep_reg;
    assign m_axis_tvalid = m_axis_tvalid_reg;
    assign m_axis_tlast  = m_axis_tlast_reg;
    
    assign s_axis_tready = s_axis_tready_reg;
    
    assign tx_busy = tx_busy_reg;
    assign tx_done = tx_done_reg;
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            state_reg <= STATE_IDLE;
            header_beat_count_reg <= 0;
        end else begin
            state_reg <= state_next;
            header_beat_count_reg <= header_beat_count_next;
        end
    end
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            rdma_opcode_reg        <= 0;
            rdma_psn_reg           <= 0;
            rdma_dest_qp_reg       <= 0;
            rdma_remote_addr_reg   <= 0;
            rdma_rkey_reg          <= 0;
            rdma_length_reg        <= 0;
            rdma_partition_key_reg <= 0;
            rdma_service_level_reg <= 0;
            fragment_id_reg        <= 0;
            more_fragments_reg     <= 0;
            fragment_offset_reg    <= 0;
        end else if (start_tx && state_reg == STATE_IDLE) begin
            rdma_opcode_reg        <= rdma_opcode;
            rdma_psn_reg           <= rdma_psn;
            rdma_dest_qp_reg       <= rdma_dest_qp;
            rdma_remote_addr_reg   <= rdma_remote_addr;
            rdma_rkey_reg          <= rdma_rkey;
            rdma_length_reg        <= rdma_length;
            rdma_partition_key_reg <= rdma_partition_key;
            rdma_service_level_reg <= rdma_service_level;
            // Latch fragmentation info for future use
            fragment_id_reg        <= fragment_id;
            more_fragments_reg     <= more_fragments;
            fragment_offset_reg    <= fragment_offset;
        end
    end
    
    always @(*) begin
        // Default assignments
        state_next = state_reg;
        header_beat_count_next = header_beat_count_reg;
        
        m_axis_tdata_reg  = 0;
        m_axis_tkeep_reg  = 0;
        m_axis_tvalid_reg = 0;
        m_axis_tlast_reg  = 0;
        
        s_axis_tready_reg = 0;
        
        tx_busy_reg = 1;
        tx_done_reg = 0;
        
        case (state_reg)
            STATE_IDLE: begin
                tx_busy_reg = 0;
                s_axis_tready_reg = 0;
                
                if (start_tx) begin
                    state_next = STATE_SEND_HEADER;
                    header_beat_count_next = 0;
                end
                else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_SEND_HEADER: begin
                m_axis_tvalid_reg = 1;
                s_axis_tready_reg = 0;  // Don't accept data yet
                m_axis_tkeep_reg = {C_AXIS_TKEEP_WIDTH{1'b1}};  // All bytes valid
                m_axis_tlast_reg = 0;  // Not last beat (data follows)
                
                // Multi-beat header transmission for 32-bit bus
                case (header_beat_count_reg)
                    //4'd0: begin
                       // m_axis_tdata_reg = 32'd0;
                    //end
                    4'd0: begin
                        m_axis_tdata_reg = {rdma_psn_reg, rdma_opcode_reg};
                    end
                    
                    4'd1: begin
                        m_axis_tdata_reg = {8'd0, rdma_dest_qp_reg};
                    end
                    
                    4'd2: begin
                        m_axis_tdata_reg = rdma_remote_addr_reg[31:0];
                    end
                    
                    4'd3: begin
                        m_axis_tdata_reg = {16'h0000, fragment_offset_reg};
                    end
                    
                    4'd4: begin
                        m_axis_tdata_reg = {rdma_length_reg};
                    end
                    
                    4'd5: begin
                        m_axis_tdata_reg = {16'h0000, rdma_partition_key_reg};
                    end
                    
                    4'd6: begin
                        m_axis_tdata_reg = {24'hababab, rdma_service_level_reg};
                    end
                    
                    default: begin
                        m_axis_tdata_reg = 32'h0;
                    end
                endcase
                
                // Advance to next beat when master is ready
                if (m_axis_tready) begin
                    if (header_beat_count_reg == HEADER_BEATS - 1) begin
                        // All header beats sent, move to data phase
                        state_next = STATE_SEND_DATA;
                        header_beat_count_next = 0;
                    end else begin
                        // Send next header beat
                        header_beat_count_next = header_beat_count_reg + 1;
                        state_next = STATE_SEND_HEADER;
                    end
                end
            end

            STATE_SEND_DATA: begin
                s_axis_tready_reg = m_axis_tready;  // Backpressure handling
                m_axis_tvalid_reg = s_axis_tvalid;
                m_axis_tdata_reg  = s_axis_tdata;
                m_axis_tkeep_reg  = s_axis_tkeep;
                m_axis_tlast_reg  = s_axis_tlast;
                
                // Transition to IDLE when last data beat is transferred
                if (s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
                    state_next = STATE_IDLE;
                    tx_done_reg = 1;
                end
                else begin
                    state_next = STATE_SEND_DATA;
                end
            end
            
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end

endmodule
