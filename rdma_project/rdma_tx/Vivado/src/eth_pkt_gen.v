module eth_pkt_gen#(
    parameter MAC_ADDR = 48'h00_0A_35_01_02_03
)(
    input  wire         aclk,
    input  wire         aresetn,

    // AXI Stream Slave (Input Data - From Data Source)
    input  wire [31:0]  s_axis_tdata,
    input  wire [3:0]   s_axis_tkeep,
    input  wire         s_axis_tvalid,
    input  wire         s_axis_tlast,
    output wire         s_axis_tready,

    // AXI Stream Master (Output Data - To Ethernet)
    output wire  [31:0] m_axis_tdata,
    output wire  [3:0]  m_axis_tkeep,
    output wire         m_axis_tvalid,
    output wire         m_axis_tlast,
    input  wire         m_axis_tready,
    
    // AXI Stream Master (Control - To Ethernet)
    output wire  [31:0] m_axis_txc_data,
    output wire  [3:0]  m_axis_txc_keep,
    output wire         m_axis_txc_valid,
    output wire         m_axis_txc_last,
    input  wire         m_axis_txc_ready
);

    localparam IDLE         = 2'b00;
    localparam SEND_CONFIG  = 2'b01;
    localparam STREAM_DATA  = 2'b10;

    reg [1:0]   rFSMcurr, wFSMnext;
    reg [2:0]   config_count;   

    // FSM State Register
    always @(posedge aclk) begin
        if (!aresetn) rFSMcurr <= IDLE;
        else          rFSMcurr <= wFSMnext;
    end

    // FSM Transition Logic
    always @(*) begin
        wFSMnext = rFSMcurr;
        case (rFSMcurr)
            IDLE: begin
                // If Data Source has data (Valid=1), we freeze it (Ready=0)
                // and transition to send configuration first.
                if (s_axis_tvalid)
                    wFSMnext = SEND_CONFIG;
            end
            
            SEND_CONFIG: begin
                // Send the 3 config words (Tag, App0, App1)
                if (m_axis_txc_ready && (config_count == 3'd5))
                    wFSMnext = STREAM_DATA;
            end

            STREAM_DATA: begin
                // Passthrough mode. Wait for end of packet (Last=1).
                // We monitor the Master Side handshake.
                if (m_axis_tvalid && m_axis_tready && m_axis_tlast)
                    wFSMnext = IDLE;
            end
            
            default: wFSMnext = IDLE;
        endcase
    end

    // --- 1. CONTROL PATH (Inject Config) ---
    // Sends the Offload Configuration to the AXI Ethernet Control Port
    assign m_axis_txc_valid = (rFSMcurr == SEND_CONFIG);
    assign m_axis_txc_last  = (rFSMcurr == SEND_CONFIG) && (config_count == 3'd5);
    assign m_axis_txc_keep  = 4'hF;

    reg [31:0] mux_txc_data;
    always @(*) begin
        case(config_count)
            3'd0: mux_txc_data = 32'hA0000000; // Tag (Normal Frame)
           // 3'd1: mux_txc_data = 32'h00000002; // Checksum Enable (Full)
            //3'd2: mux_txc_data = 32'h000E0028; // CSUM Offsets (Start 14, Insert 40)
            default: mux_txc_data = 32'h00000000;
        endcase
    end
    assign m_axis_txc_data = mux_txc_data;

    // Config Counter
    always @(posedge aclk) begin
        if (!aresetn) begin
            config_count <= 3'd0;
        end else begin
            if (rFSMcurr == IDLE) begin
                config_count <= 3'd0;
            end
            else if (rFSMcurr == SEND_CONFIG) begin
                if (m_axis_txc_valid && m_axis_txc_ready) begin
                    if (config_count == 3'd5) config_count <= 3'd0;
                    else config_count <= config_count + 1'b1;
                end
            end
        end
    end


    // --- 2. DATA PATH (Passthrough) ---
    // We connect the Input directly to the Output, but we GATE the signals
    // based on our FSM state.
    
    // Data/Keep/Last pass through directly (wires)
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tkeep  = s_axis_tkeep;
    assign m_axis_tlast  = s_axis_tlast;
    
    // Gate Valid: Only pass Valid to Ethernet when we are in STREAM_DATA
    assign m_axis_tvalid = (rFSMcurr == STREAM_DATA) ? s_axis_tvalid : 1'b0;

    // Gate Ready: Only pass Ready to Source when we are in STREAM_DATA
    // This creates the "Pause" effect while we send config.
    assign s_axis_tready = (rFSMcurr == STREAM_DATA) ? m_axis_tready : 1'b0;

endmodule