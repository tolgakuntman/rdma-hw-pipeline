`timescale 1ns / 1ps

// Simple self-checking testbench for ip_encapsulator
module ip_encapsulator_v2_tb;

    localparam DATA_WIDTH       = 64;
    localparam KEEP_WIDTH       = DATA_WIDTH / 8;
    localparam META_WIDTH       = 128;
    localparam BRAM_ADDR_WIDTH  = 8;
    localparam BRAM_DATA_WIDTH  = 192;
    localparam HEADER_BYTES     = 14 + 20 + 8; // Ethernet + IPv4 + UDP

    reg clk  = 1'b0;
    reg rstn = 1'b0;

    always #5 clk = ~clk; // 100 MHz clock

    // AXI-Stream payload input
    reg  [DATA_WIDTH-1:0]   s_axis_tdata;
    reg  [KEEP_WIDTH-1:0]   s_axis_tkeep;
    reg                     s_axis_tvalid;
    wire                    s_axis_tready;
    reg                     s_axis_tlast;
    reg                     s_axis_tuser;

    // Metadata side-channel
    reg  [META_WIDTH-1:0]   meta_tdata;
    reg                     meta_tvalid;
    wire                    meta_tready;

    // AXI-Stream output
    wire [DATA_WIDTH-1:0]   m_axis_tdata;
    wire [KEEP_WIDTH-1:0]   m_axis_tkeep;
    wire                    m_axis_tvalid;
    wire                    m_axis_tlast;
    wire                    m_axis_tuser;
    wire                    m_axis_tready;

    assign m_axis_tready = 1'b1; // always ready in this testbench

    // BRAM interface
    wire [BRAM_ADDR_WIDTH-1:0] bram_addr_b;
    wire                       bram_en_b;
    wire                       bram_clk_b;
    reg  [BRAM_DATA_WIDTH-1:0] bram_mem [0:(1<<BRAM_ADDR_WIDTH)-1];
    reg  [BRAM_DATA_WIDTH-1:0] bram_dout_reg;
    wire [BRAM_DATA_WIDTH-1:0] bram_dout_b;

    assign bram_dout_b = bram_dout_reg;

    always @(posedge clk) begin
        if (bram_en_b) begin
            bram_dout_reg <= bram_mem[bram_addr_b];
        end
    end

    // AXI-Lite slave interface (tied-off for this test)
    reg  [31:0] s_axi_awaddr  = 32'd0;
    reg         s_axi_awvalid = 1'b0;
    wire        s_axi_awready;
    reg  [31:0] s_axi_wdata   = 32'd0;
    reg  [3:0]  s_axi_wstrb   = 4'h0;
    reg         s_axi_wvalid  = 1'b0;
    wire        s_axi_wready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready  = 1'b0;

    reg  [31:0] s_axi_araddr  = 32'd0;
    reg         s_axi_arvalid = 1'b0;
    wire        s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready  = 1'b0;

    // Instantiate DUT
    ip_encapsulator #(
        .DATA_WIDTH(DATA_WIDTH),
        .KEEP_WIDTH(KEEP_WIDTH),
        .META_WIDTH(META_WIDTH),
        .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH),
        .BRAM_DATA_WIDTH(BRAM_DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rstn(rstn),

        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tuser(s_axis_tuser),

        .meta_tdata(meta_tdata),
        .meta_tvalid(meta_tvalid),
        .meta_tready(meta_tready),

        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tuser(m_axis_tuser),

        .bram_addr_b(bram_addr_b),
        .bram_en_b(bram_en_b),
        .bram_clk_b(bram_clk_b),
        .bram_dout_b(bram_dout_b),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready)
    );

    // Test parameters
    localparam [47:0] SRC_MAC = 48'h00AABBCCDDEE;
    localparam [47:0] DST_MAC = 48'h001122334455;
    localparam [31:0] SRC_IP  = 32'hC0A80101; // 192.168.1.1
    localparam [31:0] DST_IP  = 32'hC0A80102; // 192.168.1.2
    localparam [15:0] SRC_PORT = 16'd60000;
    localparam [15:0] DST_PORT = 16'd50000;
    localparam [15:0] PAYLOAD_LEN = 16'd16;
    localparam [7:0]  META_FLAGS  = 8'h00;
    localparam [7:0]  META_EP_ID  = 8'h00;

    // Payload pattern
    reg [7:0] payload_bytes [0:255];

    // Captured frame bytes
    reg [7:0] captured_bytes [0:255];
    integer frame_len;
    reg frame_done;

    // Expected frame bytes
    reg [7:0] expected_bytes [0:255];
    integer expected_len;

    // BRAM packing helper (matches endpoint_lookup entry layout)
    function [BRAM_DATA_WIDTH-1:0] pack_endpoint_entry;
        input [31:0] ip;
        input [47:0] dmac;
        input [47:0] smac;
        reg   [BRAM_DATA_WIDTH-1:0] entry;
    begin
        entry = {BRAM_DATA_WIDTH{1'b0}};
        entry[BRAM_DATA_WIDTH-1]                     = 1'b1;   // valid bit
        entry[BRAM_DATA_WIDTH-33:BRAM_DATA_WIDTH-64] = ip;
        entry[BRAM_DATA_WIDTH-65:BRAM_DATA_WIDTH-112]= dmac;
        entry[BRAM_DATA_WIDTH-113:BRAM_DATA_WIDTH-160]= smac;
        pack_endpoint_entry = entry;
    end
    endfunction

    // IPv4 checksum helper (ones' complement)
    function [15:0] calc_ipv4_checksum;
        input [15:0] total_len;
        input [15:0] identification;
        input [7:0]  ttl;
        input [7:0]  protocol;
        input [31:0] src_ip;
        input [31:0] dst_ip;
        reg   [31:0] sum;
    begin
        sum = 32'd0;
        sum = sum + 16'h4500;
        sum = sum + total_len;
        sum = sum + identification;
        sum = sum + 16'h0000; // flags/fragment offset
        sum = sum + {ttl, protocol};
        sum = sum + 16'h0000; // header checksum field zero for calculation
        sum = sum + src_ip[31:16];
        sum = sum + src_ip[15:0];
        sum = sum + dst_ip[31:16];
        sum = sum + dst_ip[15:0];
        sum = (sum[31:16] + sum[15:0]);
        sum = (sum[31:16] + sum[15:0]);
        calc_ipv4_checksum = ~sum[15:0];
    end
    endfunction

    // Capture output frame bytes
    integer byte_idx;
    always @(posedge clk) begin
        if (!rstn) begin
            frame_len  <= 0;
            frame_done <= 1'b0;
        end else begin
            if (frame_done) begin
                frame_done <= frame_done; // hold until checked
            end
            if (m_axis_tvalid && m_axis_tready) begin
                for (byte_idx = 0; byte_idx < KEEP_WIDTH; byte_idx = byte_idx + 1) begin
                    if (m_axis_tkeep[KEEP_WIDTH-1-byte_idx]) begin
                        captured_bytes[frame_len] <= m_axis_tdata[DATA_WIDTH-1 - (byte_idx*8) -: 8];
                        frame_len = frame_len + 1;
                    end
                end
                if (m_axis_tlast) begin
                    frame_done <= 1'b1;
                end
            end
        end
    end
    
    localparam [BRAM_ADDR_WIDTH-1:0] DST_INDEX = (DST_IP[BRAM_ADDR_WIDTH-1:0]) ^ (DST_IP[BRAM_ADDR_WIDTH+7:8]);

    // Stimulus
    integer i;
    initial begin
        s_axis_tdata  = {DATA_WIDTH{1'b0}};
        s_axis_tkeep  = {KEEP_WIDTH{1'b0}};
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;
        s_axis_tuser  = 1'b0;
        meta_tdata    = {META_WIDTH{1'b0}};
        meta_tvalid   = 1'b0;
        bram_dout_reg = {BRAM_DATA_WIDTH{1'b0}};
        frame_len     = 0;
        frame_done    = 1'b0;

        // Initialize BRAM contents
        for (i = 0; i < (1<<BRAM_ADDR_WIDTH); i = i + 1) begin
            bram_mem[i] = {BRAM_DATA_WIDTH{1'b0}};
        end

        // Preload endpoint table entry for DST_IP
        bram_mem[DST_INDEX] = pack_endpoint_entry(DST_IP, DST_MAC, SRC_MAC);

        // Prepare payload pattern
        for (i = 0; i < PAYLOAD_LEN; i = i + 1) begin
            payload_bytes[i] = i[7:0];
        end

        // Apply reset
        repeat (5) @(posedge clk);
        rstn = 1'b1;
        @(posedge clk);

        // Send single packet
        send_packet(PAYLOAD_LEN);

        // Wait for frame completion
        wait (frame_done);
        @(posedge clk);

        build_expected_frame(PAYLOAD_LEN);
        check_frame(PAYLOAD_LEN);

        $display("%t : TEST PASSED", $time);
        #50;
        $finish;
    end

    // Drive metadata and payload for one packet
    task send_packet;
        input [15:0] payload_len;
        integer num_beats;
        integer beat;
        integer byte_n;
        integer data_idx;
        reg [DATA_WIDTH-1:0] data_word;
        reg [KEEP_WIDTH-1:0] keep_word;
    begin
        frame_len  = 0;
        frame_done = 1'b0;

        meta_tdata  = {payload_len, SRC_IP, DST_IP, SRC_PORT, DST_PORT, META_FLAGS, META_EP_ID};
        meta_tvalid = 1'b1;
        while (!meta_tready) begin
            @(posedge clk);
        end
        @(posedge clk);
        meta_tvalid = 1'b0;

        // Wait one cycle to allow metadata alignment
        @(posedge clk);

        num_beats = (payload_len + KEEP_WIDTH - 1) / KEEP_WIDTH;
        for (beat = 0; beat < num_beats; beat = beat + 1) begin
            data_word = {DATA_WIDTH{1'b0}};
            keep_word = {KEEP_WIDTH{1'b0}};
            for (byte_n = 0; byte_n < KEEP_WIDTH; byte_n = byte_n + 1) begin
                data_idx = beat*KEEP_WIDTH + byte_n;
                if (data_idx < payload_len) begin
                    data_word[DATA_WIDTH-1 - (byte_n*8) -: 8] = payload_bytes[data_idx];
                    keep_word[KEEP_WIDTH-1-byte_n] = 1'b1;
                end else begin
                    data_word[DATA_WIDTH-1 - (byte_n*8) -: 8] = 8'h00;
                    keep_word[KEEP_WIDTH-1-byte_n] = 1'b0;
                end
            end

            s_axis_tdata  = data_word;
            s_axis_tkeep  = keep_word;
            s_axis_tlast  = (beat == num_beats-1);
            s_axis_tvalid = 1'b1;

            while (!s_axis_tready) begin
                @(posedge clk);
            end
            @(posedge clk);

            s_axis_tvalid = 1'b0;
            s_axis_tlast  = 1'b0;
            s_axis_tdata  = {DATA_WIDTH{1'b0}};
            s_axis_tkeep  = {KEEP_WIDTH{1'b0}};
        end
    end
    endtask

    // Build expected frame bytes
    task build_expected_frame;
        input [15:0] payload_len;
        reg [15:0] ip_total_length;
        reg [15:0] udp_length;
        reg [15:0] identification;
        reg [15:0] checksum_expected;
        integer idx;
        integer j;
    begin
        identification   = 16'h0000; // first packet after reset
        ip_total_length  = 16'd20 + 16'd8 + payload_len;
        udp_length       = 16'd8  + payload_len;
        checksum_expected = calc_ipv4_checksum(ip_total_length, identification, 8'd64, 8'd17, SRC_IP, DST_IP);

        expected_len = HEADER_BYTES + payload_len;

        idx = 0;
        // Ethernet header (destination MAC, source MAC, EtherType)
        for (j = 0; j < 6; j = j + 1) begin
            expected_bytes[idx] = DST_MAC[47 - (j*8) -: 8]; idx = idx + 1;
        end
        for (j = 0; j < 6; j = j + 1) begin
            expected_bytes[idx] = SRC_MAC[47 - (j*8) -: 8]; idx = idx + 1;
        end
        expected_bytes[idx] = 8'h08; idx = idx + 1;
        expected_bytes[idx] = 8'h00; idx = idx + 1;

        // IPv4 header
        expected_bytes[idx] = 8'h45; idx = idx + 1;
        expected_bytes[idx] = 8'h00; idx = idx + 1;
        expected_bytes[idx] = ip_total_length[15:8]; idx = idx + 1;
        expected_bytes[idx] = ip_total_length[7:0]; idx = idx + 1;
        expected_bytes[idx] = identification[15:8]; idx = idx + 1;
        expected_bytes[idx] = identification[7:0]; idx = idx + 1;
        expected_bytes[idx] = 8'h00; idx = idx + 1;
        expected_bytes[idx] = 8'h00; idx = idx + 1;
        expected_bytes[idx] = 8'h40; idx = idx + 1; // TTL
        expected_bytes[idx] = 8'h11; idx = idx + 1; // UDP
        expected_bytes[idx] = checksum_expected[15:8]; idx = idx + 1;
        expected_bytes[idx] = checksum_expected[7:0]; idx = idx + 1;
        for (j = 0; j < 4; j = j + 1) begin
            expected_bytes[idx] = SRC_IP[31 - (j*8) -: 8]; idx = idx + 1;
        end
        for (j = 0; j < 4; j = j + 1) begin
            expected_bytes[idx] = DST_IP[31 - (j*8) -: 8]; idx = idx + 1;
        end

        // UDP header
        expected_bytes[idx] = SRC_PORT[15:8]; idx = idx + 1;
        expected_bytes[idx] = SRC_PORT[7:0];  idx = idx + 1;
        expected_bytes[idx] = DST_PORT[15:8]; idx = idx + 1;
        expected_bytes[idx] = DST_PORT[7:0];  idx = idx + 1;
        expected_bytes[idx] = udp_length[15:8]; idx = idx + 1;
        expected_bytes[idx] = udp_length[7:0];  idx = idx + 1;
        expected_bytes[idx] = 8'h00; idx = idx + 1; // checksum high
        expected_bytes[idx] = 8'h00; idx = idx + 1; // checksum low

        // Payload bytes
        for (j = 0; j < payload_len; j = j + 1) begin
            expected_bytes[idx] = payload_bytes[j];
            idx = idx + 1;
        end
    end
    endtask

    // Check captured frame against expected values
    task check_frame;
        input [15:0] payload_len;
        integer idx;
    begin
        if (frame_len !== expected_len) begin
            $error("Frame length mismatch. Expected %0d, got %0d", expected_len, frame_len);
        end

        for (idx = 0; idx < expected_len; idx = idx + 1) begin
            if (captured_bytes[idx] !== expected_bytes[idx]) begin
                $error("Byte %0d mismatch. Expected 0x%02h, got 0x%02h", idx, expected_bytes[idx], captured_bytes[idx]);
            end
        end
    end
    endtask

endmodule