`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------
// -- Company: KUL - Group T - RDMA Team
// -- Engineer: Tubi Soyer <tugberksoyer@gmail.com>
// -- 
// -- Create Date: 22/11/2025 12:09:11 PM
// -- Design Name: 
// -- Module Name: ethernet_rx_parser
// -- Project Name: RDMA
// -- Target Devices: Kria KR260
// -- Tool Versions: 
// -- Description:
//      Parse incoming Ethernet frames and extract UDP payload
//      Input: Complete Ethernet frame (Eth + IP + UDP + Payload)
//      Output: UDP payload + metadata
//      
//      Frame structure (64-bit DATA_WIDTH):
//          Beat 0-1:   Ethernet header (14 bytes)
//          Beat 2-4:   IPv4 header (20 bytes)
//          Beat 5:     UDP header (8 bytes) + start of payload
//          Beat 6-N:   Payload data 
// -- 
// -- Dependencies: 
// -- 
// -- Revision:
// -- Revision 0.01 - File Created
// -- Additional Comments:
// -- 
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////

module ethernet_rx_parser #(
    parameter DATA_WIDTH = 64
)(
    input  wire clk,
    input  wire rstn,
    
    // AXI-Stream input (from Ethernet MAC)
    input  wire [DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire [DATA_WIDTH/8-1:0]  s_axis_tkeep,
    input  wire                     s_axis_tvalid,
    output reg                      s_axis_tready,
    input  wire                     s_axis_tlast,
    
    // AXI-Stream output (payload only)
    output reg  [DATA_WIDTH-1:0]    m_axis_tdata,
    output reg  [DATA_WIDTH/8-1:0]  m_axis_tkeep,
    output reg                      m_axis_tvalid,
    input  wire                     m_axis_tready,
    output reg                      m_axis_tlast
    
    // Statistics
    //output reg  [31:0]              rx_pkt_count,
    //output reg  [31:0]              rx_error_count
);

    // FSM states
    localparam IDLE         = 4'd0;
    localparam ETH_BEAT1    = 4'd1;  // Dst MAC + Src MAC high
    localparam ETH_BEAT2    = 4'd2;  // Src MAC low + EtherType + IP start
    localparam IP_BEAT1     = 4'd3;  // IP header beats
    localparam IP_BEAT2     = 4'd4;
    localparam IP_BEAT3     = 4'd5;  // IP end + UDP start
    localparam UDP_BEAT     = 4'd6;  // UDP header + payload start
    localparam PAYLOAD      = 4'd7;  // Forward payload
    localparam DROP         = 4'd8;  // Drop invalid packet
    
    reg [3:0] state;
    //reg [3:0] beat_count;
    
    // Header storage
    reg [47:0]  dst_mac;
    reg [47:0]  src_mac;
    reg [15:0]  ethertype;
    reg [7:0]   ip_version_ihl;
    reg [15:0]  ip_total_length;
    reg [7:0]   ip_protocol;
    reg [31:0]  src_ip;
    reg [31:0]  dst_ip;
    reg [15:0]  src_port;
    reg [15:0]  dst_port;
    reg [15:0]  udp_length;
    reg [15:0]  payload_length;
    
    // Validation flags
    reg valid_ethertype;
    reg valid_ip_version;
    reg valid_protocol;
    //reg packet_error;
    
    // Expected values
    localparam ETHERTYPE_IPV4 = 16'h0800;
    localparam IP_VERSION_4   = 8'h45;  // before 4'h4;
    localparam IP_PROTOCOL_UDP = 8'd17;
    
    // Beat counter for payload
    //reg [15:0] payload_beat_count;
    //reg [15:0] payload_beats_total;
    
    always @(posedge clk) begin
        if (!rstn) begin
            state <= IDLE;
            s_axis_tready <= 1'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tdata <= {DATA_WIDTH{1'b0}};
            m_axis_tkeep <= {DATA_WIDTH/8{1'b0}};
            m_axis_tlast <= 1'b0;
            //beat_count <= 4'd0;
            //packet_error <= 1'b0;
            //rx_pkt_count <= 32'd0;
            //rx_error_count <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    m_axis_tvalid <= 1'b0;
                    //beat_count <= 4'd0;
                    //packet_error <= 1'b0;
                    
                    s_axis_tready <= 1'b1;
                    
                    if (s_axis_tvalid && s_axis_tready) begin
                        // Beat 0: Dst MAC [47:0] + Src MAC [47:32]
                        dst_mac <= s_axis_tdata[63:16];
                        src_mac[47:32] <= s_axis_tdata[15:0];
                        state <= ETH_BEAT1;
                    end
                end
                
                ETH_BEAT1: begin
                    s_axis_tready <= 1'b1;
                    if (s_axis_tvalid && s_axis_tready) begin
                        // Beat 1: Src MAC [31:0] + EtherType [15:0] + IP [15:0]
                        src_mac[31:0] <= s_axis_tdata[63:32];
                        ethertype <= s_axis_tdata[31:16];
                        
                        // Start capturing IP header
                        ip_version_ihl <= s_axis_tdata[15:8];
                        state <= ETH_BEAT2; // added
                        // Validate EtherType
                        /*
                        if (ethertype == ETHERTYPE_IPV4 || valid_ethertype) begin
                            valid_ethertype <= 1'b1;
                            state <= ETH_BEAT2;
                        end else begin
                            valid_ethertype <= 1'b0;
                            //packet_error <= 1'b1;
                            state <= DROP;
                        end
                        */
                    end
                end
                
                ETH_BEAT2: begin
                    s_axis_tready <= 1'b1;
                    if (s_axis_tvalid && s_axis_tready) begin
                        // Beat 2: Continue IP header
                        // Capture total length, etc.
                        ip_total_length <= s_axis_tdata[63:48];
                        state <= IP_BEAT1; //added
                        // Validate IP version (should be 4)
                        /*
                        if (ip_version_ihl[7:4] == IP_VERSION_4 || valid_ip_version) begin
                            valid_ip_version <= 1'b1;
                            state <= IP_BEAT1;
                        end else begin
                            valid_ip_version <= 1'b0;
                            //packet_error <= 1'b1;
                            state <= DROP;
                        end
                        */
                    end
                end
                
                IP_BEAT1: begin
                    s_axis_tready <= 1'b1;
                    if (s_axis_tvalid && s_axis_tready) begin
                        // Beat 3: IP header continues
                        // Extract protocol, source IP
                        ip_protocol <= s_axis_tdata[47:40];
                        
                        state <= IP_BEAT2;
                    end
                end
                
                IP_BEAT2: begin
                    s_axis_tready <= 1'b1;
                    if (s_axis_tvalid && s_axis_tready) begin
                        // Beat 4: IP addresses
                        src_ip <= s_axis_tdata[63:32];
                        dst_ip <= s_axis_tdata[31:0];
                        state <= IP_BEAT3; //added
                        // Validate protocol (should be UDP)
                        /*
                        if (ip_protocol == IP_PROTOCOL_UDP || valid_protocol) begin
                            valid_protocol <= 1'b1;
                            state <= IP_BEAT3;
                        end else begin
                            valid_protocol <= 1'b0;
                            //packet_error <= 1'b1;
                            state <= DROP;
                        end
                        */
                    end
                end
                
                IP_BEAT3: begin
                    s_axis_tready <= 1'b1;
                    if (s_axis_tvalid && s_axis_tready) begin
                        // Beat 5: UDP header starts
                        src_port <= s_axis_tdata[63:48];
                        dst_port <= s_axis_tdata[47:32];
                        udp_length <= s_axis_tdata[31:16];
                        // UDP checksum in [15:0], ignore for now
                        
                        // Calculate payload length (UDP length - 8 byte UDP header)
                        payload_length <= s_axis_tdata[31:16] - 16'd8;
                        
                        state <= UDP_BEAT;
                    end
                end
                
                UDP_BEAT: begin
                
                    // We can only accept the first payload beat if
                    // the output is ready.
                    s_axis_tready <= m_axis_tready;
                
                    if (s_axis_tvalid && s_axis_tready) begin
                        
                        // Forward first payload beat
                        m_axis_tdata <= s_axis_tdata;
                        m_axis_tkeep <= s_axis_tkeep;
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast <= s_axis_tlast;
                        
                        if (s_axis_tlast) begin
                            // Single-beat payload
                            //rx_pkt_count <= rx_pkt_count + 1;
                            state <= IDLE;
                        end else begin
                            state <= PAYLOAD;
                        end
                    end
                    else begin
                        m_axis_tvalid <= 1'b0;
                    end
                end
                
                PAYLOAD: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        m_axis_tdata <= s_axis_tdata;
                        m_axis_tkeep <= s_axis_tkeep;
                        m_axis_tlast <= s_axis_tlast;
                    end
    
                    m_axis_tvalid <= s_axis_tvalid;
                    s_axis_tready <= m_axis_tready;
    
                    if (s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
                        //rx_pkt_count <= rx_pkt_count + 1;
                        state <= IDLE;
                    end
                end
                
                DROP: begin
                    // Drop invalid packet
                    s_axis_tready <= 1'b1;
                    m_axis_tvalid <= 1'b0;
                    
                    if (s_axis_tvalid && s_axis_tlast) begin
                        //rx_error_count <= rx_error_count + 1;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
