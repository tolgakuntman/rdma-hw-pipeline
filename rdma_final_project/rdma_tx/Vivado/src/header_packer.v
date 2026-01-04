`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------
// -- Company: KUL - Group T - RDMA Team
// -- Engineer: Tubi Soyer <tugberksoyer@gmail.com>
// -- 
// -- Create Date: 22/11/2025 12:09:11 PM
// -- Design Name: 
// -- Module Name: header_packer
// -- Project Name: RDMA
// -- Target Devices: Kria KR260
// -- Tool Versions: 
// -- Description: 
// -- 
// -- Dependencies: 
// -- 
// -- Revision:
// -- Revision 0.01 - File Created
// -- Additional Comments:
// -- 
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////

module header_packer #(
    parameter DATA_WIDTH = 32
)(
    input  wire                     clk,
    input  wire                     rstn,

    input  wire [111:0]             eth_header,
    input  wire                     eth_header_valid,
    output reg                      eth_header_ready,

    input  wire [159:0]             ip_header,
    input  wire                     ip_header_valid,
    output reg                      ip_header_ready,

    input  wire [63:0]              udp_header,
    input  wire                     udp_header_valid,
    output reg                      udp_header_ready,

    input  wire [15:0]              payload_length_bytes,
    input  wire                     length_valid,
    output reg                      length_ready,

    input  wire [DATA_WIDTH-1:0]    payload_in,
    input  wire [DATA_WIDTH/8-1:0]  payload_in_keep,
    input  wire                     payload_valid,
    output reg                      payload_ready,
    input  wire                     payload_last,

    output reg  [DATA_WIDTH-1:0]    m_axis_tdata,
    output reg  [DATA_WIDTH/8-1:0]  m_axis_tkeep,
    output reg                      m_axis_tvalid,
    input  wire                     m_axis_tready,
    output reg                      m_axis_tlast
);

    localparam KEEP_WIDTH = DATA_WIDTH / 8;

    localparam [2:0] ST_IDLE    = 3'd0;
    localparam [2:0] ST_HEADERS = 3'd1;
    localparam [2:0] ST_SPLIT   = 3'd2;
    localparam [2:0] ST_PAYLOAD = 3'd3;
    localparam [2:0] ST_FLUSH   = 3'd4;

    reg [2:0] state;
    reg [3:0] beat_cnt;
    reg       payload_is_empty;
    
    // Latched headers
    reg [47:0] dst_mac_r;
    reg [47:0] src_mac_r;
    reg [15:0] ethertype_r;
    reg [159:0] ip_hdr_r;
    reg [63:0]  udp_hdr_r;
    
    reg [15:0]  remainder;

    // IP/UDP fields extracted
    wire [15:0] ip_total_len = ip_hdr_r[143:128];
    wire [15:0] ip_id        = ip_hdr_r[127:112];
    wire [15:0] ip_checksum  = ip_hdr_r[79:64];
    wire [31:0] ip_src       = ip_hdr_r[63:32];
    wire [31:0] ip_dst       = ip_hdr_r[31:0];
    
    wire [15:0] udp_src_port = udp_hdr_r[63:48];
    wire [15:0] udp_dst_port = udp_hdr_r[47:32];
    wire [15:0] udp_len      = udp_hdr_r[31:16];
    wire [15:0] udp_csum     = udp_hdr_r[15:0];

    //--------------------------------------------------------------------------
    // Header Word Generation Function
    // Using a function allows instant combinatorial calculation without MUX register delays
    //--------------------------------------------------------------------------
    function [31:0] get_header_word;
        input [3:0] idx;
        begin
            case (idx)
                // Ethernet Header (14 bytes)
                // Word 0: DST_MAC[47:16]
                4'd0: get_header_word = {dst_mac_r[23:16], dst_mac_r[31:24], 
                                         dst_mac_r[39:32], dst_mac_r[47:40]};
                
                // Word 1: DST_MAC[15:0] + SRC_MAC[47:32]
                4'd1: get_header_word = {src_mac_r[39:32], src_mac_r[47:40], 
                                         dst_mac_r[7:0], dst_mac_r[15:8]};
                
                // Word 2: SRC_MAC[31:0]
                4'd2: get_header_word = {src_mac_r[7:0], src_mac_r[15:8], 
                                         src_mac_r[23:16], src_mac_r[31:24]};
                
                // Word 3: EtherType(0x0800) + IP Ver/IHL(0x45) + DSCP(0x00)
                4'd3: get_header_word = 32'h00450008;
                
                // IPv4 Header (20 bytes)
                // Word 4: IP Total Length + ID
                4'd4: get_header_word = {ip_id[7:0], ip_id[15:8], 
                                         ip_total_len[7:0], ip_total_len[15:8]};
                
                // Word 5: Flags/Frag(0x0000) + TTL(0x40) + Protocol(0x11)
                4'd5: get_header_word = 32'h11400000;
                
                // Word 6: Checksum + SrcIP[31:16]
                4'd6: get_header_word = {ip_src[23:16], ip_src[31:24], 
                                         ip_checksum[7:0], ip_checksum[15:8]};
                
                // Word 7: SrcIP[15:0] + DstIP[31:16]
                4'd7: get_header_word = {ip_dst[23:16], ip_dst[31:24], 
                                         ip_src[7:0], ip_src[15:8]};
                
                // Word 8: DstIP[15:0] + UDP SrcPort
                4'd8: get_header_word = {udp_src_port[7:0], udp_src_port[15:8], 
                                         ip_dst[7:0], ip_dst[15:8]};
                
                // Word 9: UDP DstPort + UDP Length
                4'd9: get_header_word = {udp_len[7:0], udp_len[15:8], 
                                         udp_dst_port[7:0], udp_dst_port[15:8]};
                
                default: get_header_word = 32'h0;
            endcase
        end
    endfunction

    //--------------------------------------------------------------------------
    // Main FSM
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            state            <= ST_IDLE;
            beat_cnt         <= 4'd0;
            payload_is_empty <= 1'b0;
            remainder        <= 16'h0;
            
            dst_mac_r   <= 48'h0;
            src_mac_r   <= 48'h0;
            ethertype_r <= 16'h0;
            ip_hdr_r    <= 160'h0;
            udp_hdr_r   <= 64'h0;

            m_axis_tdata  <= 32'h0;
            m_axis_tkeep  <= 4'h0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            payload_ready <= 1'b0;

            eth_header_ready <= 1'b0;
            ip_header_ready  <= 1'b0;
            udp_header_ready <= 1'b0;
            length_ready     <= 1'b0;
        end else begin
            eth_header_ready <= 1'b0;
            ip_header_ready  <= 1'b0;
            udp_header_ready <= 1'b0;
            length_ready     <= 1'b0;

            case (state)
                ST_IDLE: begin
    m_axis_tlast  <= 1'b0;
    payload_ready <= 1'b0;

    if (eth_header_valid && ip_header_valid &&
        udp_header_valid && length_valid) begin

        // Latch headers
        dst_mac_r   <= eth_header[111:64];
        src_mac_r   <= eth_header[63:16];
        ethertype_r <= eth_header[15:0];
        ip_hdr_r    <= ip_header;
        udp_hdr_r   <= udp_header;
        payload_is_empty <= (payload_length_bytes == 16'd0);

        eth_header_ready <= 1'b1;
        ip_header_ready  <= 1'b1;
        udp_header_ready <= 1'b1;
        length_ready     <= 1'b1;

        beat_cnt        <= 4'd0;
        m_axis_tvalid   <= 1'b0;   // <- don't drive data yet
        state           <= ST_HEADERS;
    end else begin
        m_axis_tvalid <= 1'b0;
    end
end

                ST_HEADERS: begin
    // when we can issue a new beat
    if (!m_axis_tvalid || m_axis_tready) begin
        m_axis_tdata  <= get_header_word(beat_cnt);
        m_axis_tkeep  <= 4'hF;
        m_axis_tvalid <= 1'b1;

        if (beat_cnt == 4'd9) begin
            // last header word
            state <= ST_SPLIT;
            // keep m_axis_tvalid asserted for this beat;
            // next cycle we'll either send split or deassert
        end else begin
            beat_cnt <= beat_cnt + 1'b1;
        end
    end
end

                ST_SPLIT: begin
                    // Word 10: UDP checksum (2 bytes) + first 2 payload bytes
                    // UDP checksum bytes in LE order: {csum[7:0], csum[15:8]}
                    
                    if (payload_is_empty) begin
                        if (!m_axis_tvalid || m_axis_tready) begin
                            m_axis_tdata  <= {16'h0000, udp_csum[7:0], udp_csum[15:8]};
                            m_axis_tkeep  <= 4'b0011;
                            m_axis_tvalid <= 1'b1;
                            m_axis_tlast  <= 1'b1;
                        end
                        
                        if (m_axis_tvalid && m_axis_tready) begin
                            m_axis_tvalid <= 1'b0;
                            m_axis_tlast  <= 1'b0;
                            state <= ST_IDLE;
                        end
                    end else begin
                        if (!m_axis_tvalid || m_axis_tready) begin
                            payload_ready <= 1'b1;
                            
                            if (payload_valid) begin
                                // UDP checksum (LE) + first 2 payload bytes
                                m_axis_tdata  <= {payload_in[15:8], payload_in[7:0], 
                                                  udp_csum[7:0], udp_csum[15:8]};
                                m_axis_tkeep  <= 4'hF;
                                m_axis_tvalid <= 1'b1;
                                
                                remainder <= payload_in[31:16];
                                
                                if (payload_last) begin
                                    m_axis_tlast  <= 1'b0;
                                    payload_ready <= 1'b0;
                                    state <= ST_FLUSH;
                                end else begin
                                    m_axis_tlast  <= 1'b0;
                                    state <= ST_PAYLOAD;
                                end
                            end else begin
                                m_axis_tvalid <= 1'b0;
                            end
                        end else begin
                            payload_ready <= 1'b0;
                        end
                    end
                end

                ST_PAYLOAD: begin
                    if (!m_axis_tvalid || m_axis_tready) begin
                        payload_ready <= 1'b1;
                        
                        if (payload_valid) begin
                            m_axis_tdata  <= {payload_in[15:8], payload_in[7:0], 
                                              remainder[15:8], remainder[7:0]};
                            m_axis_tkeep  <= 4'hF;
                            m_axis_tvalid <= 1'b1;
                            
                            remainder <= payload_in[31:16];
                            
                            if (payload_last) begin
                                m_axis_tlast  <= 1'b0;
                                payload_ready <= 1'b0;
                                state <= ST_FLUSH;
                            end else begin
                                m_axis_tlast <= 1'b0;
                            end
                        end else begin
                            m_axis_tvalid <= 1'b0;
                        end
                    end else begin
                        payload_ready <= 1'b0;
                    end
                end

                ST_FLUSH: begin
                    payload_ready <= 1'b0;
                    
                    if (!m_axis_tvalid || m_axis_tready) begin
                        m_axis_tdata  <= {16'h0000, remainder[15:8], remainder[7:0]};
                        m_axis_tkeep  <= 4'b0011;
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= 1'b1;
                    end
                    
                    if (m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
                        m_axis_tvalid <= 1'b0;
                        m_axis_tlast  <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule