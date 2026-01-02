`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------
// -- Company: KUL - Group T - RDMA Team
// -- Engineer: Tubi Soyer <tugberksoyer@gmail.com>
// -- 
// -- Create Date: 22/11/2025 12:09:11 PM
// -- Design Name: 
// -- Module Name: endpoint_lookup_tb
// -- Project Name: RDMA
// -- Target Devices: Kria KR260
// -- Tool Versions: 
// -- Description:
//      - Instantiates endpoint_lookup_bram with ADDR_WIDTH=8, BRAM_DATA_WIDTH=256
//      - Provides synchronous BRAM Port B (behavioral) and initializes several entries
//      - Drives lookup_valid with a few IPs and prints lookup results
// -- 
// -- Dependencies: 
// -- 
// -- Revision:
// -- Revision 0.01 - File Created
// -- Additional Comments:
// -- 
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////

// endpoint_lookup_tb.v
// Testbench for endpoint_lookup_bram
//
// - Instantiates endpoint_lookup_bram with ADDR_WIDTH=8, BRAM_DATA_WIDTH=256
// - Provides synchronous BRAM Port B (behavioral) and initializes several entries
// - Drives lookup_valid with a few IPs and prints lookup results

module endpoint_lookup_tb;

    // parameters must match the RTL under test
    localparam ADDR_WIDTH = 4;
    localparam BRAM_DATA_WIDTH = 256;

    reg clk = 0;
    reg rstn = 0;

    // DUT inputs
    reg  [31:0] dst_ip;
    reg         lookup_valid;

    // DUT outputs
    wire        lookup_ready;
    wire        lookup_done;
    wire        lookup_hit;
    wire        lookup_error;
    wire [47:0] dst_mac;
    wire [47:0] src_mac;

    // BRAM Port B signals (driven by TB)
    wire [ADDR_WIDTH-1:0] bram_addr_b;
    wire                  bram_en_b;
    reg  [BRAM_DATA_WIDTH-1:0] bram_dout_b;

    // Instantiate DUT
    endpoint_lookup #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .BRAM_DATA_WIDTH(BRAM_DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        .dst_ip(dst_ip),
        .lookup_valid(lookup_valid),
        .lookup_ready(lookup_ready),
        .lookup_done(lookup_done),
        .lookup_hit(lookup_hit),
        .lookup_error(lookup_error),
        .dst_mac(dst_mac),
        .src_mac(src_mac),
        .bram_addr_b(bram_addr_b),
        .bram_en_b(bram_en_b),
        .bram_dout_b(bram_dout_b)
    );

    // --------- Behavioral synchronous BRAM model for Port B ----------
    // BRAM depth 2^ADDR_WIDTH
    reg [BRAM_DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // initialize memory entries (MSB-first packing: entry_valid=1 at MSB)
    integer i;
    // helper values
        reg [31:0] ip0;
        reg [47:0] mac0;
        reg [47:0] smac0; 

        // compute shifts
        integer dst_ip_shift = BRAM_DATA_WIDTH - 64;
        integer dst_mac_shift = BRAM_DATA_WIDTH - 112;
        integer src_mac_shift = BRAM_DATA_WIDTH - 160;
       

        reg [BRAM_DATA_WIDTH-1:0] entry;
    initial begin
    
    
        for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
            mem[i] = {BRAM_DATA_WIDTH{1'b0}};
        end

        // Example: pack an entry for IP 192.168.1.10 -> dst_mac 11:22:33:44:55:66
        // Packing must match endpoint_lookup_bram slicing:
        // bit[BRAM_DATA_WIDTH-1] = valid
        // bits [BRAM_DATA_WIDTH-33 : BRAM_DATA_WIDTH-64] = dst_ip
        // bits [BRAM_DATA_WIDTH-65 : BRAM_DATA_WIDTH-112] = dst_mac (48 bits)
        // bits [BRAM_DATA_WIDTH-113 : BRAM_DATA_WIDTH-160] = src_mac (48 bits)
        // We'll construct the 256-bit word accordingly.
        
        
        ip0 = 32'hC0A8010A; // 192.168.1.10
        mac0 = 48'h112233445566;
        smac0 = 48'h000000000000;
        
        entry = {BRAM_DATA_WIDTH{1'b0}};
        entry = entry | ( ( {BRAM_DATA_WIDTH{1'b0}} | {{(BRAM_DATA_WIDTH-32){1'b0}}, ip0} ) << dst_ip_shift );
        entry = entry | ( ( {BRAM_DATA_WIDTH{1'b0}} | {{(BRAM_DATA_WIDTH-48){1'b0}}, mac0} ) << dst_mac_shift );
        entry = entry | ( ( {BRAM_DATA_WIDTH{1'b0}} | {{(BRAM_DATA_WIDTH-48){1'b0}}, smac0} ) << src_mac_shift );
        // set valid bit (MSB)
        entry[BRAM_DATA_WIDTH-1] = 1'b1;
        mem[10] = entry;

        // second sample entry:
        ip0 = 32'hC0A80114; // 192.168.1.20
        mac0 = 48'hAABBCCDDEEFF;
        entry = {BRAM_DATA_WIDTH{1'b0}};
        entry = entry | ( ( {BRAM_DATA_WIDTH{1'b0}} | {{(BRAM_DATA_WIDTH-32){1'b0}}, ip0} ) << dst_ip_shift );
        entry = entry | ( ( {BRAM_DATA_WIDTH{1'b0}} | {{(BRAM_DATA_WIDTH-48){1'b0}}, mac0} ) << dst_mac_shift );
        entry[BRAM_DATA_WIDTH-1] = 1'b1;
        mem[4] = entry; // put at index 5 (hash could map elsewhere - this is just test memory)
        
        
        $display("TB: BRAM init done (mem[0],mem[5])");
    end

    // Synchronous BRAM read behavior: data available next clock when en asserted
    always @(posedge clk) begin
        if (bram_en_b) begin
            bram_dout_b <= mem[bram_addr_b];
        end else begin
            bram_dout_b <= {BRAM_DATA_WIDTH{1'b0}};
        end
    end

    // --------- clock / reset ----------
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    initial begin
        rstn = 0;
        lookup_valid = 0;
        dst_ip = 32'd0;
        #100;
        rstn = 1;
        #50;

        // Test 1: lookup IP that maps to index 0 (we placed 192.168.1.10 at mem[0])
        $display("\nTB: Starting lookup test 1 (expect hit for 192.168.1.10)...");
        dst_ip = 32'hC0A8010A;
        lookup_valid = 1'b1;
        wait (lookup_ready == 1'b1);
        @(posedge clk);
        lookup_valid = 1'b0;

        // wait for done
        wait (lookup_done == 1'b1);
        #1;
        $display("TB: lookup_done=%b, hit=%b, error=%b, dst_mac=%012x, src_mac=%012x",
                 lookup_done, lookup_hit, lookup_error, dst_mac, src_mac);

        // Test 2: lookup IP that isn't present (expect miss)
        #20;
        $display("\nTB: Starting lookup test 2 (expect miss for 10.0.0.1)...");
        dst_ip = 32'h0A000001;
        lookup_valid = 1'b1;
        wait (lookup_ready == 1'b1);
        @(posedge clk);
        lookup_valid = 1'b0;
        wait (lookup_done == 1'b1);
        #1;
        $display("TB: lookup_done=%b, hit=%b, error=%b", lookup_done, lookup_hit, lookup_error);

        // Test 3: lookup IP in mem[5] (we loaded 192.168.1.20 into mem[5])
        #20;
        $display("\nTB: Starting lookup test 3 (expect hit for 192.168.1.20 if hash->index 5)...");
        dst_ip = 32'hC0A80114;
        lookup_valid = 1'b1;
        wait (lookup_ready == 1'b1);
        @(posedge clk);
        lookup_valid = 1'b0;
        wait (lookup_done == 1'b1);
        #1;
        $display("TB: lookup_done=%b, hit=%b, error=%b, dst_mac=%012x", lookup_done, lookup_hit, lookup_error, dst_mac);

        #50;
        $display("TB: tests complete.");
        $finish;
    end

endmodule
