`timescale 1ns / 1ps

module rx_header_parser #(
    // AXI-Stream Parameters
    parameter C_AXIS_TDATA_WIDTH = 32,
    parameter C_AXIS_TKEEP_WIDTH = 4,
    
    // RDMA Header Parameters
    parameter RDMA_OPCODE_WIDTH  = 8,
    parameter RDMA_PSN_WIDTH     = 24,
    parameter RDMA_QPN_WIDTH     = 24,
    parameter RDMA_ADDR_WIDTH    = 64,
    parameter RDMA_RKEY_WIDTH    = 32,
    parameter RDMA_LENGTH_WIDTH  = 32
) (
    input  wire                             aclk,
    input  wire                             aresetn,

    input  wire [C_AXIS_TDATA_WIDTH-1:0]    s_axis_tdata,
    input  wire [C_AXIS_TKEEP_WIDTH-1:0]    s_axis_tkeep,
    input  wire                             s_axis_tvalid,
    output wire                             s_axis_tready,
    input  wire                             s_axis_tlast,
    
    output reg  [C_AXIS_TDATA_WIDTH-1:0]    m_axis_tdata,
    output reg  [C_AXIS_TKEEP_WIDTH-1:0]    m_axis_tkeep,
    output reg                              m_axis_tvalid,
    input  wire                             m_axis_tready,
    output reg                              m_axis_tlast,
    
    output reg [RDMA_OPCODE_WIDTH-1:0]      rdma_opcode,
    output reg [RDMA_PSN_WIDTH-1:0]         rdma_psn,
    output reg [RDMA_QPN_WIDTH-1:0]         rdma_dest_qp,
    output reg [RDMA_ADDR_WIDTH-1:0]        rdma_remote_addr,
    output reg [RDMA_RKEY_WIDTH-1:0]        rdma_rkey,
    output reg [RDMA_LENGTH_WIDTH-1:0]      rdma_length,
    output reg [15:0]                       rdma_partition_key,
    output reg [7:0]                        rdma_service_level,
    
    output reg [15:0]                       fragment_id,
    output reg                              more_fragments,
    output reg [15:0]                       fragment_offset,
    
    output reg                              header_valid,     // Pulse when header is parsed
    output reg                              parsing_busy      // Parsing in progress
);

    localparam [1:0] STATE_IDLE         = 2'b00;
    localparam [1:0] STATE_PARSE_HEADER = 2'b01;
    localparam [1:0] STATE_FORWARD_DATA = 2'b10;
    
    localparam HEADER_BEATS = 7;

    reg [1:0] state_reg, state_next;

    reg [2:0] header_beat_count; // 0-6 beats

    reg [C_AXIS_TDATA_WIDTH-1:0] header_buf [0:HEADER_BEATS-1];
    
    reg s_axis_tready_reg;
    assign s_axis_tready = s_axis_tready_reg;

    reg header_complete;

    wire s_axis_hs = s_axis_tvalid && s_axis_tready;  // handshake

    always @(posedge aclk) begin
        if (!aresetn) begin
            state_reg <= STATE_IDLE;
        end else begin
            state_reg <= state_next;
        end
    end
    
    integer i;
    always @(posedge aclk) begin
        if (!aresetn) begin
            header_beat_count <= 3'd0;
            for (i = 0; i < HEADER_BEATS; i = i+1) begin
                header_buf[i] <= {C_AXIS_TDATA_WIDTH{1'b0}};
            end
        end else begin
            if (state_reg == STATE_IDLE && !s_axis_tvalid) begin
                header_beat_count <= 3'd0;
            end

            if ((state_reg == STATE_IDLE || state_reg == STATE_PARSE_HEADER) && s_axis_hs) begin
                header_buf[header_beat_count] <= s_axis_tdata;

                if (header_beat_count < HEADER_BEATS-1) begin
                    header_beat_count <= header_beat_count + 1'b1;
                end else begin
                    header_beat_count <= header_beat_count; 
                end
            end else begin
                header_beat_count <= 3'd0;
            end
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            rdma_opcode         <= {RDMA_OPCODE_WIDTH{1'b0}};
            rdma_psn            <= {RDMA_PSN_WIDTH{1'b0}};
            rdma_dest_qp        <= {RDMA_QPN_WIDTH{1'b0}};
            rdma_remote_addr    <= {RDMA_ADDR_WIDTH{1'b0}};
            rdma_rkey           <= {RDMA_RKEY_WIDTH{1'b0}};
            rdma_length         <= {RDMA_LENGTH_WIDTH{1'b0}};
            rdma_partition_key  <= 16'd0;
            rdma_service_level  <= 8'd0;
            fragment_id         <= 16'd0;
            more_fragments      <= 1'b0;
            fragment_offset     <= 16'd0;
            header_valid        <= 1'b0;
        end else begin
            header_valid <= 1'b0; // default (pulse)

            if (header_beat_count == HEADER_BEATS-1) begin
                // Beat 0: {rdma_psn[23:0], rdma_opcode[7:0]}
                rdma_opcode  <= header_buf[0][7:0];
                rdma_psn     <= header_buf[0][31:8];
                
                // Beat 1: {8'b0, rdma_dest_qp[23:0]}
                rdma_dest_qp <= header_buf[1][23:0];
                
                // Beat 2: rdma_remote_addr[31:0] (lower 32 bits)
                rdma_remote_addr <= {32'd0, header_buf[2]};
                
                // Beat 3: {16'b0, fragment_offset[15:0]}
                fragment_offset <= header_buf[3][15:0];
                
                // Beat 4: rdma_length[31:0]
                rdma_length <= header_buf[4];
                
                // Beat 5: {16'b0, rdma_partition_key[15:0]}
                rdma_partition_key <= header_buf[5][15:0];
                
                // Beat 6: {24'hababab, rdma_service_level[7:0]}
                rdma_service_level <= header_buf[6][7:0];
                
                // Future fragmentation info (not used currently)
                fragment_id    <= 16'd0;
                more_fragments <= 1'b0;
                
                header_valid <= 1'b1;
            end
        end
    end
    
    always @(*) begin
        // Defaults
        state_next        = state_reg;
        s_axis_tready_reg = 1'b0;
        
        m_axis_tdata  = {C_AXIS_TDATA_WIDTH{1'b0}};
        m_axis_tkeep  = {C_AXIS_TKEEP_WIDTH{1'b0}};
        m_axis_tvalid = 1'b0;
        m_axis_tlast  = 1'b0;
        
        parsing_busy = 1'b1;
        
        case (state_reg)
            STATE_IDLE: begin
                parsing_busy       = 1'b0;
                s_axis_tready_reg  = 1'b1;
                
                if (s_axis_tvalid && s_axis_tready_reg) begin
                    state_next = STATE_PARSE_HEADER;
                end
            end
            
            STATE_PARSE_HEADER: begin
                s_axis_tready_reg = 1'b1;

                if (s_axis_tvalid && s_axis_tready_reg &&
                    (header_beat_count == HEADER_BEATS-1)) begin
                    state_next = STATE_FORWARD_DATA;
                end
            end
            
            STATE_FORWARD_DATA: begin
                // Pass-through payload data
                m_axis_tdata  = s_axis_tdata;
                m_axis_tkeep  = s_axis_tkeep;
                m_axis_tvalid = s_axis_tvalid;
                m_axis_tlast  = s_axis_tlast;
                
                s_axis_tready_reg = m_axis_tready;
                
                if (s_axis_tvalid && m_axis_tready && s_axis_tlast) begin
                    state_next   = STATE_IDLE;
                    parsing_busy = 1'b0;
                end
            end
            
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end

endmodule
