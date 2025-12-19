`timescale 1ns/1ps
`default_nettype none

// Testbench for meta_align.v
// - Exercises enqueue and dequeue behavior
// - Toggles meta_out_ready to simulate downstream backpressure
// - Prints inputs and outputs and checks ordering
//
// Author: ChatGPT
// Date: 2025-11-01

module meta_align_tb;

    // Parameters for DUT
    localparam DEPTH = 4;

    // Clock / reset
    reg clk;
    reg rstn;

    // DUT I/O
    reg          tb_meta_valid;
    wire         tb_meta_ready;
    reg  [31:0]  tb_meta_src_ip;
    reg  [31:0]  tb_meta_dst_ip;
    reg  [15:0]  tb_meta_src_port;
    reg  [15:0]  tb_meta_dst_port;
    reg  [31:0]  tb_meta_payload_len;
    reg  [15:0]  tb_meta_dst_index;
    reg  [15:0]  tb_meta_flags;

    wire         tb_meta_out_valid;
    reg          tb_meta_out_ready;
    wire [191:0] tb_meta_out_bus;

    wire         tb_almost_full;
    wire         tb_full;
    wire         tb_empty;

    // Instantiate DUT
    meta_align #(
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rstn(rstn),
        .meta_valid(tb_meta_valid),
        .meta_ready(tb_meta_ready),
        .meta_src_ip(tb_meta_src_ip),
        .meta_dst_ip(tb_meta_dst_ip),
        .meta_src_port(tb_meta_src_port),
        .meta_dst_port(tb_meta_dst_port),
        .meta_payload_len(tb_meta_payload_len),
        .meta_dst_index(tb_meta_dst_index),
        .meta_flags(tb_meta_flags),
        .meta_out_valid(tb_meta_out_valid),
        .meta_out_ready(tb_meta_out_ready),
        .meta_out_bus(tb_meta_out_bus),
        .almost_full(tb_almost_full),
        .full(tb_full),
        .empty(tb_empty)
    );

    // Clock generation: 10 ns period => 100 MHz
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Test vectors storage (for verification)
    reg [191:0] sent_vec [0:15]; // store up to 16 entries for checking
    integer send_count;
    integer recv_count;

    // Helper task to pack meta fields (same format as module)
    function [191:0] pack_meta;
        input [31:0] src_ip;
        input [31:0] dst_ip;
        input [15:0] src_port;
        input [15:0] dst_port;
        input [31:0] payload_len;
        input [15:0] dst_index;
        input [15:0] flags;
        begin
            pack_meta = {
                16'h0000,           // reserved [191:176]
                flags,              // [175:160]
                payload_len,        // [159:128]
                dst_ip,             // [127:96]
                src_ip,             // [95:64]
                dst_index,          // [63:48]
                16'h0000,           // reserved [47:32]
                dst_port,           // [31:16]
                src_port            // [15:0]
            };
        end
    endfunction

    // Stimulus and verification
    initial begin
        // initialize
        rstn = 1'b0;
        tb_meta_valid = 1'b0;
        tb_meta_src_ip = 32'h0;
        tb_meta_dst_ip = 32'h0;
        tb_meta_src_port = 16'h0;
        tb_meta_dst_port = 16'h0;
        tb_meta_payload_len = 32'h0;
        tb_meta_dst_index = 16'hFFFF;
        tb_meta_flags = 16'h0;
        tb_meta_out_ready = 1'b0;

        send_count = 0;
        recv_count = 0;

        // Reset pulse
        #20;
        @(posedge clk);
        rstn = 1'b1; // release reset
        $display("[%0t] Reset released", $time);

        // Wait a bit then start driving meta entries
        #20;

        // Sequence 1: enqueue DEPTH entries back-to-back (should fill FIFO)
        $display("[%0t] Enqueue %0d entries back-to-back (DEPTH=%0d)", $time, DEPTH, DEPTH);
        repeat (DEPTH) begin
            @(posedge clk);
            tb_meta_src_ip      <= 32'h0a000001 + send_count; // 10.0.0.1 + n
            tb_meta_dst_ip      <= 32'h0a0000ff - send_count; // 10.0.0.255 - n
            tb_meta_src_port    <= 16'h1000 + send_count;
            tb_meta_dst_port    <= 16'h2000 + send_count;
            tb_meta_payload_len <= 32'h00000100 + send_count; // increasing lengths
            tb_meta_dst_index   <= send_count[15:0];
            tb_meta_flags       <= 16'h0001; // flag example
            tb_meta_valid       <= 1'b1;

            // Wait one cycle and check meta_ready
            @(posedge clk);
            if (!tb_meta_ready) begin
                $display("[%0t] WARNING: meta_ready low when trying to enqueue index %0d", $time, send_count);
            end else begin
                sent_vec[send_count] = pack_meta(tb_meta_src_ip, tb_meta_dst_ip, tb_meta_src_port, tb_meta_dst_port, tb_meta_payload_len, tb_meta_dst_index, tb_meta_flags);
                $display("[%0t] Enqueued meta idx=%0d", $time, send_count);
                send_count = send_count + 1;
            end
            // deassert valid (drive pulses)
            tb_meta_valid <= 1'b0;
        end

        // Now allow dequeue with intermittent backpressure
        #10;
        $display("[%0t] Start dequeuing with intermittent backpressure", $time);
        repeat (send_count + 2) begin
            @(posedge clk);
            // Toggle meta_out_ready pseudo-randomly (simulate consumer busy)
            tb_meta_out_ready <= ($random % 2) ? 1'b1 : 1'b0;
            if (tb_meta_out_valid && tb_meta_out_ready) begin
                $display("[%0t] Dequeued meta bus = %032h", $time, tb_meta_out_bus);
                // verify order
                if (tb_meta_out_bus !== sent_vec[recv_count]) begin
                    $display("[%0t] ERROR: dequeued data mismatch at recv_count=%0d", $time, recv_count);
                    $display(" expected %032h", sent_vec[recv_count]);
                    $display(" received %032h", tb_meta_out_bus);
                    $finish;
                end else begin
                    $display("[%0t] OK: dequeued matches index %0d", $time, recv_count);
                end
                recv_count = recv_count + 1;
            end
        end

        // Test wrap-around: enqueue more entries to exercise pointer wrap
        /*
        $display("[%0t] Enqueue 6 more entries to test wrap-around", $time);
        integer k;
        for (k = 0; k < 6; k = k + 1) begin
            @(posedge clk);
            tb_meta_src_ip      <= 32'hC0A80001 + k; // 192.168.0.1 + k
            tb_meta_dst_ip      <= 32'hC0A800FF - k;
            tb_meta_src_port    <= 16'h3000 + k;
            tb_meta_dst_port    <= 16'h4000 + k;
            tb_meta_payload_len <= 32'h00001000 + k;
            tb_meta_dst_index   <= (send_count + k);
            tb_meta_flags       <= 16'h0002;
            tb_meta_valid       <= 1'b1;
            @(posedge clk);
            if (tb_meta_ready) begin
                sent_vec[send_count] = pack_meta(tb_meta_src_ip, tb_meta_dst_ip, tb_meta_src_port, tb_meta_dst_port, tb_meta_payload_len, tb_meta_dst_index, tb_meta_flags);
                $display("[%0t] Enqueued wrap meta idx=%0d", $time, send_count);
                send_count = send_count + 1;
            end else begin
                $display("[%0t] Could not enqueue wrap meta idx=%0d (fifo full)", $time, send_count);
            end
            tb_meta_valid <= 1'b0;
        end
        */

        // Dequeue remaining items (set meta_out_ready always 1)
        #10;
        tb_meta_out_ready <= 1'b1;
        #200;

        // Final check: recv_count should equal send_count (all consumed)
        if (recv_count != send_count) begin
            $display("[%0t] ERROR: mismatch send_count=%0d recv_count=%0d", $time, send_count, recv_count);
            $finish;
        end else begin
            $display("[%0t] PASS: all enqueued metadata dequeued properly (count=%0d)", $time, recv_count);
        end

        #20;
        $display("[%0t] Testbench completed successfully", $time);
        $finish;
    end

    // Optional monitoring display (status every few cycles)
    initial begin
        $display("Starting meta_align testbench...");
        $display("Time    meta_ready meta_out_valid meta_out_ready count full empty");
        forever begin
            @(posedge clk);
            if (rstn) begin
                $display("[%0t]    %b         %b            %b           %0d     %b    %b", $time, tb_meta_ready, tb_meta_out_valid, tb_meta_out_ready, dut.count, tb_full, tb_empty);
            end
        end
    end

endmodule

`default_nettype wire
