----------------------------------------------------------------------------------
-- Company: KUL - Group T - RDMA Team
-- Engineer: Emir Yalcin <emir.yalcin@hotmail.com>
-- 
-- Create Date: 22/11/2025 12:09:11 PM
-- Design Name: 
-- Module Name: axis_rx_to_bram
-- Project Name: RDMA
-- Target Devices: Kria KR260
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
// eth_axis_patgen.v
// AXI Ethernet 1G/2.5G TX pattern generator
module eth_axis_patgen (
    input  wire        axis_clk,
    input  wire        axis_aresetn,
    input  wire        enable,       

    // ---- TX DATA stream -> axi_ethernet_0.s_axis_txd_* ----
    output reg  [31:0] txd_tdata,
    output reg  [3:0]  txd_tkeep,
    output reg         txd_tvalid,
    input  wire        txd_tready,
    output reg         txd_tlast,

    // ---- TX CTRL stream -> axi_ethernet_0.s_axis_txc_* ----
    output reg  [31:0] txc_tdata,
    output reg  [3:0]  txc_tkeep,
    output reg         txc_tvalid,
    input  wire        txc_tready,
    output reg         txc_tlast
);

    localparam integer CTRL_WORDS  = 6;      
    localparam integer DATA_BYTES  = 76;     // 76 byte = 19 word @ 32 bit
    localparam integer DATA_WORDS  = DATA_BYTES/4;

    localparam [1:0]
        ST_IDLE      = 2'd0,
        ST_SEND_CTRL = 2'd1,
        ST_SEND_DATA = 2'd2;

    reg [1:0] state    = ST_IDLE;
    reg [2:0] ctrl_idx = 3'd0;      // 0..5
    reg [4:0] data_idx = 5'd0;      // 0..18

    // --------------------------------------------------------
    // Ethernet frame bytes (TX pattern)
    // --------------------------------------------------------
    reg [7:0] frame_bytes [0:DATA_BYTES-1];
    integer i;
    reg frame_init_done = 1'b0;

    always @(posedge axis_clk) begin
        if (!axis_aresetn) begin
            frame_init_done <= 1'b0;
        end else if (!frame_init_done) begin
            // Dest MAC: FF:FF:FF:FF:FF:FF
            frame_bytes[0]  <= 8'hFF;
            frame_bytes[1]  <= 8'hFF;
            frame_bytes[2]  <= 8'hFF;
            frame_bytes[3]  <= 8'hFF;
            frame_bytes[4]  <= 8'hFF;
            frame_bytes[5]  <= 8'hFF;

            // Src MAC: 00:0A:35:01:02:03
            frame_bytes[6]  <= 8'h00;
            frame_bytes[7]  <= 8'h0A;
            frame_bytes[8]  <= 8'h35;
            frame_bytes[9]  <= 8'h01;
            frame_bytes[10] <= 8'h02;
            frame_bytes[11] <= 8'h03;

            // EtherType
            frame_bytes[12] <= 8'h88;
            frame_bytes[13] <= 8'hB5;

            // Payload 60 byte: 0x00..0x3B
            for (i = 0; i < 60; i = i+1)
                frame_bytes[14+i] <= i[7:0];

            for (i = 14+60; i < DATA_BYTES; i = i+1)
                frame_bytes[i] <= 8'h00;

            frame_init_done <= 1'b1;
        end
    end

    always @(posedge axis_clk) begin
        if (!axis_aresetn) begin
            state      <= ST_IDLE;
            ctrl_idx   <= 3'd0;
            data_idx   <= 5'd0;

            txd_tdata  <= 32'h0;
            txd_tkeep  <= 4'h0;
            txd_tvalid <= 1'b0;
            txd_tlast  <= 1'b0;

            txc_tdata  <= 32'h0;
            txc_tkeep  <= 4'h0;
            txc_tvalid <= 1'b0;
            txc_tlast  <= 1'b0;
        end else begin
           
            txd_tvalid <= 1'b0;
            txd_tlast  <= 1'b0;
            txc_tvalid <= 1'b0;
            txc_tlast  <= 1'b0;
       
            txd_tkeep  <= 4'b1111;
            txc_tkeep  <= 4'b1111;

            case (state)
                // --------------------
                ST_IDLE: begin
                    ctrl_idx <= 3'd0;
                    data_idx <= 5'd0;
                    if (enable)        
                        state <= ST_SEND_CTRL;
                end
               
                ST_SEND_CTRL: begin
                    txc_tvalid <= 1'b1;

                    case (ctrl_idx)
                        3'd0: txc_tdata <= 32'hA0000000; // Flag = 0xA (Normal Transmit)
                        default: txc_tdata <= 32'h00000000; 
                    endcase

                    if (ctrl_idx == CTRL_WORDS-1)
                        txc_tlast <= 1'b1;

                    if (txc_tvalid && txc_tready) begin
                        if (ctrl_idx == CTRL_WORDS-1) begin
                            ctrl_idx <= 3'd0;
                            state    <= ST_SEND_DATA;
                        end else begin
                            ctrl_idx <= ctrl_idx + 1'b1;
                        end
                    end
                end
          
                ST_SEND_DATA: begin
                    txd_tvalid <= 1'b1;

                    //4 byte -> 1 word (little endian)
                    txd_tdata[7:0]   <= frame_bytes[4*data_idx + 0];
                    txd_tdata[15:8]  <= frame_bytes[4*data_idx + 1];
                    txd_tdata[23:16] <= frame_bytes[4*data_idx + 2];
                    txd_tdata[31:24] <= frame_bytes[4*data_idx + 3]; 


                    if (data_idx == DATA_WORDS-1)
                        txd_tlast <= 1'b1;

                    if (txd_tvalid && txd_tready) begin
                        if (data_idx == DATA_WORDS-1) begin
                            data_idx <= 5'd0;
                            state    <= ST_IDLE;  
                        end else begin
                            data_idx <= data_idx + 1'b1;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
