`timescale 1ns / 1ps

module ethernet_rx_parser_v2_tb;

    // Parameters
    parameter DATA_WIDTH = 64;
    parameter CLK_PERIOD = 10; // 100 MHz

    // Signals
    reg                   clk;
    reg                   rstn;
    
    // AXI-Stream Input (Slave Interface of DUT)
    reg [DATA_WIDTH-1:0]  s_axis_tdata;
    reg [DATA_WIDTH/8-1:0] s_axis_tkeep;
    reg                   s_axis_tvalid;
    wire                  s_axis_tready;
    reg                   s_axis_tlast;

    // AXI-Stream Output (Master Interface of DUT)
    wire [DATA_WIDTH-1:0] m_axis_tdata;
    wire [DATA_WIDTH/8-1:0] m_axis_tkeep;
    wire                  m_axis_tvalid;
    reg                   m_axis_tready;
    wire                  m_axis_tlast;

    // DUT Instance
    ethernet_rx_parser #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test Procedure
    initial begin
        // Initialize signals
        rstn = 0;
        s_axis_tdata = 0;
        s_axis_tkeep = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        m_axis_tready = 0; // Simulate downstream not ready initially

        // Reset Sequence
        #(CLK_PERIOD * 10);
        rstn = 1;
        #(CLK_PERIOD * 5);
        
        $display("--- Starting Simulation ---");

        // Enable downstream receiver
        m_axis_tready = 1;

        // --- Test Case 1: Short Packet (1 beat of payload, PASS) ---
        $display("[Time %0t] Test 1: Sending Short Packet (PASS)", $time);
        // Payload data: 0xAABBCCDDEEFF0011
        send_udp_packet(64'hAA_BB_CC_DD_EE_FF_00_11, 1);
        
        #(CLK_PERIOD * 5);

        // --- Test Case 2: Long Packet (4 beats of payload, PASS) ---
        $display("[Time %0t] Test 2: Sending Long Packet (PASS)", $time);
        //send_long_udp_packet(4);

        #(CLK_PERIOD * 5);
        
        /*
        // --- Test Case 3: Invalid EtherType (FAIL: DROP state expected) ---
        $display("[Time %0t] Test 3: Sending Invalid EtherType (Expect DROP)", $time);
        // BEAT 0: Dst MAC + Src MAC High
        send_axis_word(64'h000A35000102_000A, 8'hFF, 0); 
        
        // BEAT 1: Src MAC Low + Ethertype (0800 -> FFFF, invalid) + IP Ver (45) + TOS (00)
        // EtherType is FFFF, which should fail the check in ETH_BEAT1 and transition to DROP.
        // We still send the remaining beats, but the DUT should ignore them.
        send_axis_word(64'h35000001_FFFF_4500, 8'hFF, 0); 

        send_axis_word(64'h0030_1234_4000_0000, 8'hFF, 0);
        send_axis_word(64'h40_11_0000_C0A8, 8'hFF, 0);
        send_axis_word(64'h0001_C0A80002, 8'hFF, 0);
        send_axis_word(64'h1388_2710_001C_0000, 8'hFF, 0);
        send_axis_word(64'hDEADBEEF_BEEFCAFE, 8'hFF, 1); // Last beat
        
        #(CLK_PERIOD * 5);

        // --- Test Case 4: Valid EtherType, Invalid IP Protocol (FAIL: DROP state expected) ---
        $display("[Time %0t] Test 4: Sending Invalid IP Protocol (Expect DROP)", $time);
        // BEAT 0: Dst MAC + Src MAC High
        send_axis_word(64'h000A35000102_000A, 8'hFF, 0); 
        
        // BEAT 1: Src MAC Low + Ethertype (0800 - OK) + IP Ver (45) + TOS (00)
        send_axis_word(64'h35000001_0800_4500, 8'hFF, 0);

        // BEAT 2: IP Len + ID + Frag
        send_axis_word(64'h0030_1234_4000_0000, 8'hFF, 0); 

        // BEAT 3: TTL + Proto (17=UDP -> 06=TCP, not UDP) + Cksum + SrcIP High
        // Protocol is 06, which should fail the check in IP_BEAT2 and transition to DROP.
        send_axis_word(64'h40_06_0000_C0A8, 8'hFF, 0); 

        // Remaining beats must be sent and discarded until tlast
        send_axis_word(64'h0001_C0A80002, 8'hFF, 0);
        send_axis_word(64'h1388_2710_001C_0000, 8'hFF, 0);
        send_axis_word(64'hDEADBEEF_BEEFCAFE, 8'hFF, 1); // Last beat


        #(CLK_PERIOD * 20);
        
        */
        $display("--- Simulation Finished ---");
        $finish;
    end

    // Monitor Process: specific for checking output
    always @(posedge clk) begin
        if (m_axis_tvalid && m_axis_tready) begin
            $display("[Output Monitor] Time: %0t | Data: %h | Last: %b", 
                     $time, m_axis_tdata, m_axis_tlast);
        end
    end

    // -----------------------------------------------------------
    // Task: Send a packet with logic matching the FSM states
    // -----------------------------------------------------------
    task send_udp_packet(input [63:0] payload_data, input integer payload_beats);
        integer i;
        begin
            // Based on your FSM, the headers consume 6 beats (IDLE -> IP_BEAT3)
            // The 7th beat (UDP_BEAT) is the first payload beat.
            
            // BEAT 0: Dst MAC + Src MAC High
            // Dst: 00:0A:35:00:01:02, Src: 00:0A:35:00:00:01
            send_axis_word(64'h000A35000102_000A, 8'hFF, 0); 
            
            // BEAT 1: Src MAC Low + Ethertype (0800) + IP Ver (45) + TOS (00)
            // Note: Your FSM expects big endian mapping in tdata for slicing
            send_axis_word(64'h35000001_0800_4500, 8'hFF, 0);

            // BEAT 2: IP Len + ID + Frag
            send_axis_word(64'h0030_1234_4000_0000, 8'hFF, 0); // Padding lower bits

            // BEAT 3: TTL + Proto (17=UDP) + Cksum + SrcIP High
            send_axis_word(64'h40_11_0000_C0A8, 8'hFF, 0);

            // BEAT 4: SrcIP Low + DstIP
            send_axis_word(64'h0001_C0A80002, 8'hFF, 0);

            // BEAT 5: SrcPort + DstPort + Len + Cksum
            send_axis_word(64'h1388_2710_001C_0000, 8'hFF, 0);

            // BEAT 6 (UDP_BEAT): First beat of payload
            // This is where your FSM starts forwarding
            send_axis_word(payload_data, 8'hFF, 1); // tlast=1 for single beat
        end
    endtask

    // -----------------------------------------------------------
    // Task: Send a multi-beat packet
    // -----------------------------------------------------------
    task send_long_udp_packet(input integer num_payload_beats);
        integer i;
        begin
            // --- HEADER BEATS (0 to 5) ---
            send_axis_word(64'h000A35000102_000A, 8'hFF, 0); // Beat 0
            send_axis_word(64'h35000001_0800_4500, 8'hFF, 0); // Beat 1
            send_axis_word(64'h0030_1234_4000_0000, 8'hFF, 0); // Beat 2
            send_axis_word(64'h40_11_0000_C0A8, 8'hFF, 0);    // Beat 3
            send_axis_word(64'h0001_C0A80002, 8'hFF, 0);      // Beat 4
            send_axis_word(64'h1388_2710_001C_0000, 8'hFF, 0); // Beat 5

            // --- PAYLOAD BEATS ---
            for (i = 0; i < num_payload_beats; i = i + 1) begin
                if (i == num_payload_beats - 1)
                    // Use valid Hex: DEAD_BEEF
                    send_axis_word(64'hDEADBEEF_00000000 + i, 8'hFF, 1); // Last beat
                else
                    // Use valid Hex: AA_BB_CC_DD
                    send_axis_word(64'hAABBCCDD_00000000 + i, 8'hFF, 0);
            end
        end
    endtask

    // -----------------------------------------------------------
    // Low-level helper to drive AXI Stream bus
    // -----------------------------------------------------------
    task send_axis_word(
        input [DATA_WIDTH-1:0] data,
        input [DATA_WIDTH/8-1:0] keep,
        input last
    );
        begin
            s_axis_tvalid <= 1;
            s_axis_tdata  <= data;
            s_axis_tkeep  <= keep;
            s_axis_tlast  <= last;
            
            // Wait for clock and ready
            @(posedge clk);
            while (!s_axis_tready) @(posedge clk);
            
            // Deassert valid after acceptance (simulation style)
            // For back-to-back, we wouldn't drop valid, but this is safer for viewing
            s_axis_tvalid <= 0; 
            s_axis_tlast  <= 0;
        end
    endtask

endmodule