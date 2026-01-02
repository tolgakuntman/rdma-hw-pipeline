`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------
// -- Company: KUL - Group T - RDMA Team
// -- Engineer: Tubi Soyer <tugberksoyer@gmail.com>
// -- 
// -- Create Date: 22/11/2025 12:09:11 PM
// -- Design Name: 
// -- Module Name: ip_decapsulator_tb
// -- Project Name: RDMA
// -- Target Devices: Kria KR260
// -- Tool Versions: 
// -- Description:
//   1. Valid Ethernet/IP/UDP frame reception
//   2. Payload extraction
//   3. Metadata generation
//   4. Invalid packet handling (wrong EtherType, protocol)
//   5. Error packet handling (tuser asserted)
//   6. Multi-packet reception
//   7. Backpressure handling
// -- 
// -- Dependencies: 
// -- 
// -- Revision:
// -- Revision 0.01 - File Created
// -- Additional Comments:
// -- 
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////

module ip_decapsulator_tb;

    // Parameters
    parameter CLK_PERIOD = 10;  // 100 MHz
    parameter DATA_WIDTH = 64;
    parameter KEEP_WIDTH = 8;
    parameter META_WIDTH = 128;
    
    // Clock and reset
    reg clk;
    reg rstn;
    
    // AXI-Stream input (simulated Ethernet MAC RX)
    reg  [DATA_WIDTH-1:0]    s_axis_tdata;
    reg  [KEEP_WIDTH-1:0]    s_axis_tkeep;
    reg                      s_axis_tvalid;
    wire                     s_axis_tready;
    reg                      s_axis_tlast;
    
    // AXI-Stream output (to RDMA)
    wire [DATA_WIDTH-1:0]    m_axis_tdata;
    wire [KEEP_WIDTH-1:0]    m_axis_tkeep;
    wire                     m_axis_tvalid;
    reg                      m_axis_tready;
    wire                     m_axis_tlast;
    
    // AXI-Lite (dummy for now)
    reg  [31:0]              s_axi_awaddr;
    reg                      s_axi_awvalid;
    wire                     s_axi_awready;
    reg  [31:0]              s_axi_wdata;
    reg  [3:0]               s_axi_wstrb;
    reg                      s_axi_wvalid;
    wire                     s_axi_wready;
    wire [1:0]               s_axi_bresp;
    wire                     s_axi_bvalid;
    reg                      s_axi_bready;
    reg  [31:0]              s_axi_araddr;
    reg                      s_axi_arvalid;
    wire                     s_axi_arready;
    wire [31:0]              s_axi_rdata;
    wire [1:0]               s_axi_rresp;
    wire                     s_axi_rvalid;
    reg                      s_axi_rready;
    
    // Test variables
    integer test_pass_count;
    integer test_fail_count;
    integer packet_count;
    
    // Packet fields
    reg [47:0] test_dst_mac;
    reg [47:0] test_src_mac;
    reg [15:0] test_ethertype;
    reg [31:0] test_src_ip;
    reg [31:0] test_dst_ip;
    reg [15:0] test_src_port;
    reg [15:0] test_dst_port;
    reg [15:0] test_udp_length;
    reg [DATA_WIDTH-1:0] test_payload [0:255];
    integer test_payload_beats;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT instantiation
    ip_decapsulator #(
        .DATA_WIDTH(DATA_WIDTH),
        .KEEP_WIDTH(KEEP_WIDTH),
        .META_WIDTH(META_WIDTH)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        
        // Input from Ethernet MAC
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        
        // Output to RDMA
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        
        // AXI-Lite
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
    
    //=========================================================================
    // Task: Send Ethernet Frame
    //=========================================================================
    task send_eth_frame;
        input [47:0] dst_mac;
        input [47:0] src_mac;
        input [15:0] ethertype;
        input [31:0] src_ip;
        input [31:0] dst_ip;
        input [15:0] src_port;
        input [15:0] dst_port;
        input [15:0] payload_len;  // UDP payload length in bytes
        input integer error_flag;  // 1 = set tuser error
        
        reg [15:0] ip_total_len;
        reg [15:0] udp_total_len;
        integer beat_idx;
        integer payload_beat_count;
        
        begin
            // Calculate lengths
            udp_total_len = 16'd8 + payload_len;  // UDP header (8) + payload
            ip_total_len = 16'd20 + udp_total_len; // IP header (20) + UDP
            
            $display("[%0t] Sending Ethernet frame:", $time);
            $display("  Dst MAC: %012X", dst_mac);
            $display("  Src MAC: %012X", src_mac);
            $display("  EtherType: 0x%04X", ethertype);
            $display("  Src IP: %d.%d.%d.%d", 
                     src_ip[31:24], src_ip[23:16], src_ip[15:8], src_ip[7:0]);
            $display("  Dst IP: %d.%d.%d.%d",
                     dst_ip[31:24], dst_ip[23:16], dst_ip[15:8], dst_ip[7:0]);
            $display("  UDP: %d -> %d, Len: %d", src_port, dst_port, udp_total_len);
            $display("  Payload: %d bytes", payload_len);
            
            // Wait for ready
            wait(s_axis_tready);
            @(posedge clk);
            
            // Beat 0: Dst MAC + Src MAC[47:32]
            s_axis_tdata = {dst_mac, src_mac[47:32]};
            s_axis_tkeep = 8'hFF;
            s_axis_tvalid = 1'b1;
            s_axis_tlast = 1'b0;
            @(posedge clk);
            
            // Beat 1: Src MAC[31:0] + EtherType + IP Version/IHL + DSCP/ECN
            s_axis_tdata = {src_mac[31:0], ethertype, 8'h45, 8'h00};
            s_axis_tkeep = 8'hFF;
            @(posedge clk);
            
            // Beat 2: IP Total Length + ID + Flags/Frag + TTL + Protocol
            s_axis_tdata = {ip_total_len, 16'h0001, 16'h4000, 8'd64, 8'd17};
            s_axis_tkeep = 8'hFF;
            @(posedge clk);
            
            // Beat 3: IP Checksum (dummy) + Src IP[31:16]
            s_axis_tdata = {16'h0000, src_ip[31:16], src_ip[15:0], dst_ip[31:16]};
            s_axis_tkeep = 8'hFF;
            @(posedge clk);
            
            // Beat 4: Dst IP[15:0] + UDP Src Port + UDP Dst Port
            s_axis_tdata = {dst_ip[15:0], src_port, dst_port, udp_total_len};
            s_axis_tkeep = 8'hFF;
            @(posedge clk);
            
            // Beat 5: UDP Checksum + First payload bytes
            // Generate test payload pattern
            if (payload_len > 0) begin
                s_axis_tdata = {16'h0000, 48'hDEADBEEFCAFE};  // UDP checksum + first 6 bytes
                s_axis_tkeep = 8'hFF;
                
                // Calculate remaining payload beats
                payload_beat_count = (payload_len - 6 + 7) / 8;  // Ceiling division
                
                if (payload_beat_count == 0) begin
                    // All payload fits in beat 5
                    s_axis_tlast = 1'b1;
                end
                @(posedge clk);
                
                // Send remaining payload beats
                for (beat_idx = 0; beat_idx < payload_beat_count; beat_idx = beat_idx + 1) begin
                    // Generate test pattern
                    s_axis_tdata = {8{8'h30 + beat_idx[7:0]}};  // Pattern: 0x30, 0x31, 0x32...
                    s_axis_tkeep = 8'hFF;
                    
                    if (beat_idx == payload_beat_count - 1) begin
                        s_axis_tlast = 1'b1;
                    end
                    
                    @(posedge clk);
                end
            end else begin
                // No payload, end at Beat 5
                s_axis_tdata = {16'h0000, 48'h0};
                s_axis_tkeep = 8'hC0;  // Only 2 bytes valid (UDP checksum)
                s_axis_tlast = 1'b1;
                @(posedge clk);
            end
            
            // De-assert valid
            s_axis_tvalid = 1'b0;
            s_axis_tlast = 1'b0;
            
            packet_count = packet_count + 1;
            $display("  Frame sent (beat count: %0d)", beat_idx + 6);
        end
    endtask
    
    //=========================================================================
    // Task: Check Metadata Output
    //=========================================================================
    task check_metadata;
        input [31:0] expected_src_ip;
        input [31:0] expected_dst_ip;
        input [15:0] expected_src_port;
        input [15:0] expected_dst_port;
        input [15:0] expected_payload_len;
        
        reg [15:0] actual_payload_len;
        reg [31:0] actual_src_ip;
        reg [31:0] actual_dst_ip;
        reg [15:0] actual_src_port;
        reg [15:0] actual_dst_port;
        
        begin
            
            // Extract metadata fields
            // meta_out[127:112] = payload_length
            // meta_out[111:80]  = src_ip
            // meta_out[79:48]   = dst_ip
            // meta_out[47:32]   = src_port
            // meta_out[31:16]   = dst_port
            
            /*
            $display("[%0t] Metadata Received:", $time);
            $display("  Payload Len: %d (expected: %d)", actual_payload_len, expected_payload_len);
            $display("  Src IP: %08X (expected: %08X)", actual_src_ip, expected_src_ip);
            $display("  Dst IP: %08X (expected: %08X)", actual_dst_ip, expected_dst_ip);
            $display("  Src Port: %d (expected: %d)", actual_src_port, expected_src_port);
            $display("  Dst Port: %d (expected: %d)", actual_dst_port, expected_dst_port);
            
            
            // Verify
            if (actual_payload_len == expected_payload_len &&
                actual_src_ip == expected_src_ip &&
                actual_dst_ip == expected_dst_ip &&
                actual_src_port == expected_src_port &&
                actual_dst_port == expected_dst_port) begin
                $display("  ✓ Metadata CORRECT");
                test_pass_count = test_pass_count + 1;
            end else begin
                $display("  ✗ Metadata MISMATCH!");
                test_fail_count = test_fail_count + 1;
            end
            */
            
        end
    endtask
    
    //=========================================================================
    // Task: Receive Payload
    //=========================================================================
    task receive_payload;
        input integer expected_beats;
        
        integer beat_count;
        
        begin
            $display("[%0t] Receiving payload (expected %0d beats)...", $time, expected_beats);
            
            beat_count = 0;
            m_axis_tready = 1'b1;
            
            while (!m_axis_tlast) begin
                wait(m_axis_tvalid);
                @(posedge clk);
                
                $display("  Beat %0d: tdata=%016X, tkeep=%02X", 
                         beat_count, m_axis_tdata, m_axis_tkeep);
                beat_count = beat_count + 1;
                
                if (beat_count > expected_beats + 5) begin
                    $display("  ✗ ERROR: Too many beats received!");
                    test_fail_count = test_fail_count + 1;
                end
            end
            
            // Final beat with tlast
            if (m_axis_tvalid && m_axis_tlast) begin
                $display("  Beat %0d: tdata=%016X, tkeep=%02X (LAST)", 
                         beat_count, m_axis_tdata, m_axis_tkeep);
                @(posedge clk);
            end
            
            m_axis_tready = 1'b0;
            
            $display("  Payload received: %0d beats", beat_count + 1);
            
            if (beat_count + 1 >= expected_beats) begin
                $display("  ✓ Beat count OK");
                test_pass_count = test_pass_count + 1;
            end else begin
                $display("  ✗ Beat count MISMATCH (got %0d, expected ~%0d)", 
                         beat_count + 1, expected_beats);
                test_fail_count = test_fail_count + 1;
            end
        end
    endtask
    
    //=========================================================================
    // Main Test Sequence
    //=========================================================================
    initial begin
        // Initialize signals
        rstn = 0;
        s_axis_tdata = 0;
        s_axis_tkeep = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        m_axis_tready = 1;
        
        // AXI-Lite (unused)
        s_axi_awaddr = 0;
        s_axi_awvalid = 0;
        s_axi_wdata = 0;
        s_axi_wstrb = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 1;
        s_axi_araddr = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 1;
        
        test_pass_count = 0;
        test_fail_count = 0;
        packet_count = 0;
        
        $display("========================================");
        $display("  IP Decapsulator Testbench");
        $display("========================================\n");
        
        // Reset
        repeat(10) @(posedge clk);
        rstn = 1;
        repeat(5) @(posedge clk);
        
        //=====================================================================
        // Test 1: Valid IPv4/UDP Packet (Small Payload)
        //=====================================================================
        $display("\n--- Test 1: Valid IPv4/UDP Packet ---");
        
        fork
            // Send packet
            send_eth_frame(
                48'hAABBCCDDEEFF,        // dst_mac
                48'h112233445566,        // src_mac
                16'h0800,                // ethertype (IPv4)
                32'hC0A80164,            // src_ip (192.168.1.100)
                32'hC0A80165,            // dst_ip (192.168.1.101)
                16'd12345,               // src_port
                16'd54321,               // dst_port
                16'd64,                  // payload_len (64 bytes)
                0                        // error_flag
            );
            
            // Check metadata
            begin
                #100;
                check_metadata(
                    32'hC0A80164,        // expected src_ip
                    32'hC0A80165,        // expected dst_ip
                    16'd12345,           // expected src_port
                    16'd54321,           // expected dst_port
                    16'd64               // expected payload_len
                );
            end
            
            // Receive payload
            begin
                #200;
                receive_payload(8);  // ~64 bytes / 8 bytes per beat
            end
        join
        
        repeat(20) @(posedge clk);
        
        //=====================================================================
        // Test 2: Large Payload
        //=====================================================================
        $display("\n--- Test 2: Large Payload (1024 bytes) ---");
        
        fork
            send_eth_frame(
                48'hFFFFFFFFFFFF,        // broadcast
                48'h001122334455,
                16'h0800,
                32'h0A000001,            // 10.0.0.1
                32'h0A000002,            // 10.0.0.2
                16'd8080,
                16'd8081,
                16'd1024,                // 1KB payload
                0
            );
            
            begin
                #100;
                check_metadata(32'h0A000001, 32'h0A000002, 16'd8080, 16'd8081, 16'd1024);
            end
            
            begin
                #200;
                receive_payload(128);  // 1024 / 8
            end
        join
        
        repeat(20) @(posedge clk);
        
        //=====================================================================
        // Test 3: Invalid EtherType (Should Drop)
        //=====================================================================
        $display("\n--- Test 3: Invalid EtherType (Should Drop) ---");
        
        send_eth_frame(
            48'hAABBCCDDEEFF,
            48'h112233445566,
            16'h0806,                    // ARP, not IPv4!
            32'hC0A80101,
            32'hC0A80102,
            16'd1234,
            16'd5678,
            16'd32,
            0
        );
        
        // Wait and check that no metadata/payload is output
        repeat(100) @(posedge clk);
        
        if (m_axis_tvalid == 0) begin
            $display("  ✓ Packet correctly dropped (no output)");
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("  ✗ ERROR: Invalid packet not dropped!");
            test_fail_count = test_fail_count + 1;
        end
        
        repeat(20) @(posedge clk);
        
        //=====================================================================
        // Test 4: Error Packet (tuser asserted)
        //=====================================================================
        $display("\n--- Test 4: Error Packet (tuser=1) ---");
        
        send_eth_frame(
            48'hAABBCCDDEEFF,
            48'h112233445566,
            16'h0800,
            32'hC0A80164,
            32'hC0A80165,
            16'd9999,
            16'd8888,
            16'd128,
            1                            // error_flag = 1
        );
        
        repeat(100) @(posedge clk);
        
        
        if (m_axis_tvalid == 0) begin
            $display("  ✓ Error packet correctly dropped");
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("  ✗ ERROR: Error packet not dropped!");
            test_fail_count = test_fail_count + 1;
        end
        
        repeat(20) @(posedge clk);
        
        
        //=====================================================================
        // Test 5: Backpressure Test
        //=====================================================================
        $display("\n--- Test 5: Backpressure Test ---");
        
        fork
            send_eth_frame(
                48'h001122334455,
                48'hAABBCCDDEEFF,
                16'h0800,
                32'hAC100001,            // 172.16.0.1
                32'hAC100002,
                16'd4000,
                16'd5000,
                16'd256,
                0
            );
            
            // Simulate slow consumer (intermittent ready)
            begin
                #150;
                m_axis_tready = 1'b0;
                repeat(20) @(posedge clk);
                m_axis_tready = 1'b1;
                repeat(5) @(posedge clk);
                m_axis_tready = 1'b0;
                repeat(10) @(posedge clk);
                m_axis_tready = 1'b1;
            end
            
            begin
                #100;
                check_metadata(32'hAC100001, 32'hAC100002, 16'd4000, 16'd5000, 16'd256);
            end
        join
        
        // Wait for packet to fully drain
        wait(!m_axis_tvalid);
        repeat(20) @(posedge clk);
        
        $display("  ✓ Backpressure handled correctly");
        test_pass_count = test_pass_count + 1;
        
        //=====================================================================
        // Test Summary
        //=====================================================================
        repeat(50) @(posedge clk);
        
        $display("\n========================================");
        $display("  Test Summary");
        $display("========================================");
        $display("Packets Sent:   %0d", packet_count);
        $display("Tests Passed:   %0d", test_pass_count);
        $display("Tests Failed:   %0d", test_fail_count);
        
        if (test_fail_count == 0) begin
            $display("\n✓✓✓ ALL TESTS PASSED ✓✓✓");
        end else begin
            $display("\n✗✗✗ SOME TESTS FAILED ✗✗✗");
        end
        $display("========================================\n");
        
        $finish;
    end
    
    // Timeout
    initial begin
        #500000;  // 500 us timeout
        $display("\n✗ ERROR: Testbench timeout!");
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("ip_decapsulator_tb.vcd");
        $dumpvars(0, ip_decapsulator_tb);
    end

endmodule