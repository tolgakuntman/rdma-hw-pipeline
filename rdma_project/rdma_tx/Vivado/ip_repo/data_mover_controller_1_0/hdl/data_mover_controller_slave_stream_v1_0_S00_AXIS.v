module data_mover_controller_slave_stream_v1_0_S00_AXIS #
(
  parameter integer C_S_AXIS_TDATA_WIDTH = 32
)
(
  // RDMA SQ Entry Outputs
  output reg [31:0]   rdma_id,
  output reg [15:0]   rdma_opcode,
  output reg [15:0]   rdma_flags,
  output reg [63:0]   rdma_local_key,
  output reg [63:0]   rdma_remote_key,
  output reg [127:0]  rdma_btt,
  output reg [191:0]  rdma_reserved,
  output reg          rdma_entry_valid,

  // AXIS
  input  wire                      S_AXIS_ACLK,
  input  wire                      S_AXIS_ARESETN,
  output wire                      S_AXIS_TREADY,
  input  wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
  input  wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
  input  wire                      S_AXIS_TLAST,
  input  wire                      S_AXIS_TVALID
);

  localparam NUMBER_OF_INPUT_WORDS = 16;

  // simple 1-bit FSM
  localparam IDLE       = 1'b0;
  localparam RECEIVE    = 1'b1;

  reg        state;
  reg [3:0]  word_count;

  // buffer for 16 × 32-bit words
  reg [C_S_AXIS_TDATA_WIDTH-1:0] stream_data_buf [0:NUMBER_OF_INPUT_WORDS-1];

  wire axis_tready = (state == RECEIVE);
  assign S_AXIS_TREADY = axis_tready;

  // FSM
  always @(posedge S_AXIS_ACLK) begin
    if (!S_AXIS_ARESETN) begin
      state            <= IDLE;
      word_count       <= 4'd0;
      rdma_entry_valid <= 1'b0;
    end else begin
      rdma_entry_valid <= 1'b0; // default: pulse

      case (state)
        IDLE: begin
          if (S_AXIS_TVALID) begin
            state      <= RECEIVE;
            word_count <= 4'd0;
          end
          else begin
            state <= IDLE;
          end
        end

        RECEIVE: begin
          if (S_AXIS_TVALID && axis_tready) begin
            stream_data_buf[word_count] <= S_AXIS_TDATA;
            word_count                  <= word_count + 1'b1;

            if (word_count == NUMBER_OF_INPUT_WORDS-1) begin
              // got all 16 words → decode
              state <= IDLE;

              // parse fields (word 15 comes from S_AXIS_TDATA, rest from buffer)
              rdma_id         <= stream_data_buf[0];             // bytes 0-3
              rdma_opcode     <= stream_data_buf[1][15:0];       // bytes 4-5
              rdma_flags      <= stream_data_buf[1][31:16];      // bytes 6-7
              rdma_local_key  <= {stream_data_buf[3],
                                  stream_data_buf[2]};           // bytes 8-15
              rdma_remote_key <= {stream_data_buf[5],
                                  stream_data_buf[4]};           // bytes 16-23
              rdma_btt        <= {stream_data_buf[9],
                                  stream_data_buf[8],
                                  stream_data_buf[7],
                                  stream_data_buf[6]};           // bytes 24-39
              rdma_reserved   <= {S_AXIS_TDATA,                  // word 15 (current)
                                  stream_data_buf[14],
                                  stream_data_buf[13],
                                  stream_data_buf[12],
                                  stream_data_buf[11],
                                  stream_data_buf[10]};          // bytes 40-63

              rdma_entry_valid <= 1'b1;
            end
            else begin
                state <= RECEIVE;
            end
          end
          else begin
            state <= RECEIVE;
          end
        end
      endcase
    end
  end

endmodule