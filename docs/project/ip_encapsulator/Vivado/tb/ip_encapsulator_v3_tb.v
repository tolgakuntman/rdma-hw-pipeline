`timescale 1ns / 1ps

// Comprehensive stimulus for ip_encapsulator
module ip_encapsulator_v3_tb;

    // ------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------
    localparam DATA_WIDTH       = 64;
    localparam KEEP_WIDTH       = DATA_WIDTH / 8;
    localparam META_WIDTH       = 128;
    localparam BRAM_ADDR_WIDTH  = 8;
    localparam BRAM_DATA_WIDTH  = 192;
    localparam HEADER_BYTES     = 14 + 20 + 8;
    localparam MAX_FRAME_BYTES  = 512;
    localparam MAX_FRAMES       = 8;

    localparam CLK_PERIOD = 10; // 100 MHz

    // ------------------------------------------------------------------
    // Clocks / reset
    // ------------------------------------------------------------------
    reg clk  = 1'b0;
    reg rstn = 1'b0;

    always #(CLK_PERIOD/2) clk = ~clk;

    // ------------------------------------------------------------------
    // AXI-Stream payload input
    // ------------------------------------------------------------------
    reg  [DATA_WIDTH-1:0]   s_axis_tdata;
    reg  [KEEP_WIDTH-1:0]   s_axis_tkeep;
    reg                     s_axis_tvalid;
    wire                    s_axis_tready;
    reg                     s_axis_tlast;

    // Metadata side channel
    reg  [META_WIDTH-1:0]   meta_tdata;
    reg                     meta_tvalid;
    wire                    meta_tready;

    // AXI-Stream output (always ready in TB)
    wire [DATA_WIDTH-1:0]   m_axis_tdata;
    wire [KEEP_WIDTH-1:0]   m_axis_tkeep;
    wire                    m_axis_tvalid;
    wire                    m_axis_tlast;
    wire                    m_axis_tready;

    assign m_axis_tready = 1'b1;

    // ------------------------------------------------------------------
    // BRAM endpoint table model
    // ------------------------------------------------------------------
    wire [BRAM_ADDR_WIDTH-1:0] bram_addr_b;
    wire                       bram_en_b;
    wire                       bram_clk_b;
    reg  [BRAM_DATA_WIDTH-1:0] bram_dout_reg;
    reg  [BRAM_DATA_WIDTH-1:0] bram_mem [0:(1<<BRAM_ADDR_WIDTH)-1];

    assign bram_clk_b  = clk;
    assign bram_dout_b = bram_dout_reg;

    wire [BRAM_DATA_WIDTH-1:0] bram_dout_b;

    always @(posedge clk) begin
        if (bram_en_b) begin
            bram_dout_reg <= bram_mem[bram_addr_b];
        end
    end

    // ------------------------------------------------------------------
    // AXI-Lite (unused in this TB, left idle)
    // ------------------------------------------------------------------
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

    // ------------------------------------------------------------------
    // DUT instantiation
    // ------------------------------------------------------------------
    ip_encapsulator #(
        .DATA_WIDTH      (DATA_WIDTH),
        .KEEP_WIDTH      (KEEP_WIDTH),
        .META_WIDTH      (META_WIDTH),
        .BRAM_ADDR_WIDTH (BRAM_ADDR_WIDTH),
        .BRAM_DATA_WIDTH (BRAM_DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rstn(rstn),

        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),

        .meta_tdata(meta_tdata),
        .meta_tvalid(meta_tvalid),
        .meta_tready(meta_tready),

        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),

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

    // ------------------------------------------------------------------
    // Scenario constants
    // ------------------------------------------------------------------
    localparam [47:0] SRC_MAC  = 48'h00AABBCCDDEE;
    localparam [47:0] DST_MAC  = 48'h001122334455;
    localparam [31:0] SRC_IP   = 32'h0A000001; // 10.0.0.1
    localparam [31:0] DST_IP_A = 32'h0A000002; // 10.0.0.2
    localparam [31:0] DST_IP_B = 32'h0A000003; // 10.0.0.3
    localparam [31:0] DST_IP_MISS = 32'h0A0000FF; // no table entry
    localparam [15:0] SRC_PORT = 16'd60000;
    localparam [15:0] DST_PORT = 16'd50000;

    // Lookup error tracker
    integer lookup_error_count;
    reg     lookup_error_d;
    wire    lookup_error_w = dut.lookup_error;

    always @(posedge clk) begin
        if (!rstn) begin
            lookup_error_count <= 0;
            lookup_error_d     <= 1'b0;
        end else begin
            lookup_error_d <= lookup_error_w;
            if (lookup_error_w && !lookup_error_d) begin
                lookup_error_count <= lookup_error_count + 1;
            end
        end
    end

    // ------------------------------------------------------------------
    // Payload pattern buffer (per packet)
    // ------------------------------------------------------------------
    reg [7:0] payload_buf [0:MAX_FRAME_BYTES-1];

    // ------------------------------------------------------------------
    // Output capture arrays
    // ------------------------------------------------------------------
    reg [7:0] captured_bytes [0:MAX_FRAMES-1][0:MAX_FRAME_BYTES-1];
    integer   frame_length   [0:MAX_FRAMES-1];
    integer   frame_count;
    reg [15:0] cur_frame_len;
    integer byte_index;
    reg [15:0] next_len;

    always @(posedge clk) begin
        if (!rstn) begin
            frame_count   <= 0;
            cur_frame_len <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                next_len = cur_frame_len;
                for (byte_index = 0; byte_index < KEEP_WIDTH; byte_index = byte_index + 1) begin
                    if (m_axis_tkeep[KEEP_WIDTH-1-byte_index]) begin
                        captured_bytes[frame_count][next_len] <= m_axis_tdata[DATA_WIDTH-1 - (byte_index*8) -: 8];
                        next_len = next_len + 1;
                    end
                end
                if (m_axis_tlast) begin
                    frame_length[frame_count] <= next_len;
                    frame_count   <= frame_count + 1;
                    cur_frame_len <= 0;
                end else begin
                    cur_frame_len <= next_len;
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Expected frame storage
    // ------------------------------------------------------------------
    reg [7:0] expected_bytes [0:MAX_FRAMES-1][0:MAX_FRAME_BYTES-1];
    integer   expected_length[0:MAX_FRAMES-1];
    integer   expected_count;

    // ------------------------------------------------------------------
    // Helper functions / tasks
    // ------------------------------------------------------------------

    // Pack endpoint entry into BRAM word
    function [BRAM_DATA_WIDTH-1:0] pack_endpoint_entry;
        input [31:0] ip;
        input [47:0] dmac;
        input [47:0] smac;
        reg   [BRAM_DATA_WIDTH-1:0] entry;
    begin
        entry = {BRAM_DATA_WIDTH{1'b0}};
        entry[BRAM_DATA_WIDTH-1]                      = 1'b1; // valid
        entry[BRAM_DATA_WIDTH-33:BRAM_DATA_WIDTH-64]  = ip;
        entry[BRAM_DATA_WIDTH-65:BRAM_DATA_WIDTH-112] = dmac;
        entry[BRAM_DATA_WIDTH-113:BRAM_DATA_WIDTH-160]= smac;
        pack_endpoint_entry = entry;
    end
    endfunction

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
        sum = sum + 16'h0000;
        sum = sum + {ttl, protocol};
        sum = sum + 16'h0000;
        sum = sum + src_ip[31:16];
        sum = sum + src_ip[15:0];
        sum = sum + dst_ip[31:16];
        sum = sum + dst_ip[15:0];
        sum = (sum[31:16] + sum[15:0]);
        sum = (sum[31:16] + sum[15:0]);
        calc_ipv4_checksum = ~sum[15:0];
    end
    endfunction

    task preload_payload;
        input integer length;
        input [7:0]  seed;
        integer k;
    begin
        for (k = 0; k < length; k = k + 1) begin
            payload_buf[k] = seed + k;
        end
    end
    endtask

    task drive_metadata;
        input [15:0] payload_len;
        input [31:0] src_ip;
        input [31:0] dst_ip;
        input [15:0] src_port;
        input [15:0] dst_port;
        input [7:0]  flags;
        input [7:0]  ep_id;
    begin
        // Wait until meta_align is ready to accept metadata
        while (!meta_tready) begin
            @(posedge clk);
        end
        meta_tdata  = {payload_len, src_ip, dst_ip, src_port, dst_port, flags, ep_id};
        meta_tvalid = 1'b1;
        @(posedge clk);
        // Deassert after one cycle - meta_align will capture it internally
        meta_tvalid = 1'b0;
        // Wait one cycle to allow meta_align to transition to WAIT_PAYLOAD state
        @(posedge clk);
    end
    endtask

    task drive_payload;
        input [15:0] payload_len;
        integer beats;
        integer beat;
        integer b;
        integer idx;
        reg [DATA_WIDTH-1:0]   data_word;
        reg [KEEP_WIDTH-1:0]   keep_word;
    begin
        beats = (payload_len + KEEP_WIDTH - 1) / KEEP_WIDTH;
        if (beats == 0) begin
            // Zero-length payload: send one beat with tkeep=0 and tlast=1
            // This satisfies meta_align's requirement for at least one beat
            s_axis_tdata  = {DATA_WIDTH{1'b0}};
            s_axis_tkeep  = {KEEP_WIDTH{1'b0}}; // No valid bytes
            s_axis_tvalid = 1'b1;
            s_axis_tlast  = 1'b1;

            @(posedge clk);
            while (!s_axis_tready) begin
                @(posedge clk);
            end

            s_axis_tvalid = 1'b0;
            s_axis_tlast  = 1'b0;
            s_axis_tdata  = {DATA_WIDTH{1'b0}};
            s_axis_tkeep  = {KEEP_WIDTH{1'b0}};
        end else begin
            for (beat = 0; beat < beats; beat = beat + 1) begin
                data_word = {DATA_WIDTH{1'b0}};
                keep_word = {KEEP_WIDTH{1'b0}};
                for (b = 0; b < KEEP_WIDTH; b = b + 1) begin
                    idx = beat*KEEP_WIDTH + b;
                    if (idx < payload_len) begin
                        data_word[DATA_WIDTH-1 - (b*8) -: 8] = payload_buf[idx];
                        keep_word[KEEP_WIDTH-1-b] = 1'b1;
                    end
                end
                s_axis_tdata  = data_word;
                s_axis_tkeep  = keep_word;
                s_axis_tvalid = 1'b1;
                s_axis_tlast  = (beat == beats-1);

                @(posedge clk);
                while (!s_axis_tready) begin
                    @(posedge clk);
                end

                s_axis_tvalid = 1'b0;
                s_axis_tlast  = 1'b0;
                s_axis_tdata  = {DATA_WIDTH{1'b0}};
                s_axis_tkeep  = {KEEP_WIDTH{1'b0}};
            end
        end
    end
    endtask

    task build_expected_frame;
        input integer frame_idx;
        input [15:0] payload_len;
        input [7:0]  seed;
        input        mac_hit;
        input [47:0] dst_mac;
        input [47:0] src_mac;
        input [31:0] dst_ip;
        input [15:0] identification;
        integer idx;
        integer j;
        reg [15:0] ip_total_length;
        reg [15:0] udp_length;
        reg [15:0] checksum;
        reg [47:0] dst_mac_sel;
        reg [47:0] src_mac_sel;
    begin
        ip_total_length = 16'd20 + 16'd8 + payload_len;
        udp_length      = 16'd8 + payload_len;
        checksum        = calc_ipv4_checksum(ip_total_length, identification, 8'd64, 8'd17, SRC_IP, dst_ip);
        dst_mac_sel     = mac_hit ? dst_mac : 48'd0;
        src_mac_sel     = mac_hit ? src_mac : 48'd0;

        expected_length[frame_idx] = HEADER_BYTES + payload_len;
        idx = 0;

        for (j = 0; j < 6; j = j + 1) begin
            expected_bytes[frame_idx][idx] = dst_mac_sel[47 - (j*8) -: 8]; idx = idx + 1;
        end
        for (j = 0; j < 6; j = j + 1) begin
            expected_bytes[frame_idx][idx] = src_mac_sel[47 - (j*8) -: 8]; idx = idx + 1;
        end
        expected_bytes[frame_idx][idx] = 8'h08; idx = idx + 1;
        expected_bytes[frame_idx][idx] = 8'h00; idx = idx + 1;

        expected_bytes[frame_idx][idx] = 8'h45; idx = idx + 1;
        expected_bytes[frame_idx][idx] = 8'h00; idx = idx + 1;
        expected_bytes[frame_idx][idx] = ip_total_length[15:8]; idx = idx + 1;
        expected_bytes[frame_idx][idx] = ip_total_length[7:0]; idx = idx + 1;
        expected_bytes[frame_idx][idx] = identification[15:8]; idx = idx + 1;
        expected_bytes[frame_idx][idx] = identification[7:0]; idx = idx + 1;
        expected_bytes[frame_idx][idx] = 8'h00; idx = idx + 1;
        expected_bytes[frame_idx][idx] = 8'h00; idx = idx + 1;
        expected_bytes[frame_idx][idx] = 8'h40; idx = idx + 1;
        expected_bytes[frame_idx][idx] = 8'h11; idx = idx + 1;
        expected_bytes[frame_idx][idx] = checksum[15:8]; idx = idx + 1;
        expected_bytes[frame_idx][idx] = checksum[7:0]; idx = idx + 1;
        for (j = 0; j < 4; j = j + 1) begin
            expected_bytes[frame_idx][idx] = SRC_IP[31 - (j*8) -: 8]; idx = idx + 1;
        end
        for (j = 0; j < 4; j = j + 1) begin
            expected_bytes[frame_idx][idx] = dst_ip[31 - (j*8) -: 8]; idx = idx + 1;
        end

        expected_bytes[frame_idx][idx] = SRC_PORT[15:8]; idx = idx + 1;
        expected_bytes[frame_idx][idx] = SRC_PORT[7:0];  idx = idx + 1;
        expected_bytes[frame_idx][idx] = DST_PORT[15:8]; idx = idx + 1;
        expected_bytes[frame_idx][idx] = DST_PORT[7:0];  idx = idx + 1;
        expected_bytes[frame_idx][idx] = udp_length[15:8]; idx = idx + 1;
        expected_bytes[frame_idx][idx] = udp_length[7:0];  idx = idx + 1;
        expected_bytes[frame_idx][idx] = 8'h00;           idx = idx + 1;
        expected_bytes[frame_idx][idx] = 8'h00;           idx = idx + 1;

        for (j = 0; j < payload_len; j = j + 1) begin
            expected_bytes[frame_idx][idx] = (seed + j);
            idx = idx + 1;
        end
    end
    endtask

    task send_and_expect;
        input [15:0] payload_len;
        input [31:0] dst_ip;
        input [7:0]  seed;
        input        expect_hit;
        integer id_val;
    begin
        preload_payload(payload_len, seed);
        drive_metadata(payload_len, SRC_IP, dst_ip, SRC_PORT, DST_PORT, 8'h00, 8'h01);
        drive_payload(payload_len);

        id_val = expected_count;
        build_expected_frame(expected_count, payload_len, seed, expect_hit, DST_MAC, SRC_MAC, dst_ip, id_val[15:0]);
        expected_count = expected_count + 1;
    end
    endtask

    task check_frames;
        integer f;
        integer b;
    begin
        for (f = 0; f < expected_count; f = f + 1) begin
            if (frame_length[f] !== expected_length[f]) begin
                $error("Frame %0d length mismatch. Expected %0d, got %0d", f, expected_length[f], frame_length[f]);
            end
            for (b = 0; b < expected_length[f]; b = b + 1) begin
                if (captured_bytes[f][b] !== expected_bytes[f][b]) begin
                    $error("Frame %0d byte %0d mismatch. Expected 0x%02h, got 0x%02h", f, b, expected_bytes[f][b], captured_bytes[f][b]);
                end
            end
        end
    end
    endtask

    // ------------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------------
    integer addr;
    initial begin
        s_axis_tdata  = {DATA_WIDTH{1'b0}};
        s_axis_tkeep  = {KEEP_WIDTH{1'b0}};
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;
        meta_tdata    = {META_WIDTH{1'b0}};
        meta_tvalid   = 1'b0;
        bram_dout_reg = {BRAM_DATA_WIDTH{1'b0}};

        frame_count     = 0;
        expected_count  = 0;

        // Clear BRAM contents
        for (addr = 0; addr < (1<<BRAM_ADDR_WIDTH); addr = addr + 1) begin
            bram_mem[addr] = {BRAM_DATA_WIDTH{1'b0}};
        end

        // Program endpoint entries for DST_IP_A and DST_IP_B
        bram_mem[(DST_IP_A[BRAM_ADDR_WIDTH-1:0]) ^ (DST_IP_A[BRAM_ADDR_WIDTH+7:8])] = pack_endpoint_entry(DST_IP_A, DST_MAC, SRC_MAC);
        bram_mem[(DST_IP_B[BRAM_ADDR_WIDTH-1:0]) ^ (DST_IP_B[BRAM_ADDR_WIDTH+7:8])] = pack_endpoint_entry(DST_IP_B, DST_MAC, SRC_MAC);

        // Assert reset
        repeat (8) @(posedge clk);
        rstn = 1'b1;
        @(posedge clk);

        // Scenario 1: zero-length payload (header only)
        send_and_expect(16'd0, DST_IP_A, 8'h10, 1'b1);

        // Scenario 2: short payload (less than one beat)
        send_and_expect(16'd5, DST_IP_A, 8'h20, 1'b1);

        // Scenario 3: multi-beat payload
        send_and_expect(16'd40, DST_IP_B, 8'h30, 1'b1);

        // Scenario 4: immediate back-to-back payload (no idle)
        send_and_expect(16'd12, DST_IP_B, 8'h40, 1'b1);

        // Scenario 5: lookup miss
        send_and_expect(16'd8, DST_IP_MISS, 8'h50, 1'b0);

        // allow pipeline to drain
        repeat (50) @(posedge clk);

        if (frame_count !== expected_count) begin
            $error("Frame count mismatch. Expected %0d, got %0d", expected_count, frame_count);
        end

        check_frames();

        if (lookup_error_count !== 1) begin
            $error("Expected exactly one lookup error pulse, observed %0d", lookup_error_count);
        end

        $display("%t : All tests completed. Frame count=%0d", $time, frame_count);
        #100;
        $finish;
    end

endmodule
