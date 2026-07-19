//------------------------------------------------------------------------------
// Module      : cp_inserter
//
// Purpose:
//   - Insert a cyclic prefix of length `CP_LEN` into each row of the
//     time-domain MxN frame, producing an M x (N+CP_LEN) output frame suitable
//     for transmission or DAC playback.
//
// Behavior / Algorithm:
//   1. On `frame_valid`, for each row r:
//       a. Copy the last `CP_LEN` samples from `frame[*][N-CP_LEN .. N-1]`
//          into the prefix positions `out_bank[r*(N+CP_LEN) + 0..CP_LEN-1]`.
//       b. Copy the payload samples `frame[*][0..N-1]` into subsequent
//          positions to form the contiguous output frame row.
//   2. Enter S_STREAM state and present `out_bank` words to the external
//      interface while honoring `out_ready` backpressure; assert `frame_done`
//      when the entire M*(N+CP_LEN) words are transmitted.
//
// Notes:
//   - The operation is a deterministic memory rearrangement and does not
//     perform arithmetic on the payload samples. It is designed to be
//     synthesizable with minimal BRAM/FF overhead.
//------------------------------------------------------------------------------
module cp_inserter #(
    parameter int M         = 4,
    parameter int N         = 4,
    parameter int CP_LEN    = 2,
    parameter int IN_WIDTH  = 7,
    parameter int OUT_WIDTH = IN_WIDTH
)(
    input  logic clk,
    input  logic rst_n,

    input  logic frame_valid,
    input  logic signed [IN_WIDTH-1:0] frame_i [0:M-1][0:N-1],
    input  logic signed [IN_WIDTH-1:0] frame_q [0:M-1][0:N-1],

    output logic out_valid,
    input  logic out_ready,
    output logic signed [OUT_WIDTH-1:0] out_i,
    output logic signed [OUT_WIDTH-1:0] out_q,
    output logic busy,
    output logic frame_done
);

    localparam int TOTAL = M * (N + CP_LEN);
    localparam int IDX_W = (TOTAL <= 1) ? 1 : $clog2(TOTAL);

    typedef enum logic [1:0] {
        S_IDLE,
        S_LOAD,
        S_STREAM
    } state_t;

    state_t state;
    logic [IDX_W-1:0] load_count;
    logic [IDX_W-1:0] out_count;

    logic signed [OUT_WIDTH-1:0] out_bank_i [0:TOTAL-1];
    logic signed [OUT_WIDTH-1:0] out_bank_q [0:TOTAL-1];

    integer r;
    integer c;
    integer lin;
    integer out_lin;

    assign busy = (state != S_IDLE);
    assign out_valid = (state == S_STREAM);
    assign out_i = out_bank_i[out_count];
    assign out_q = out_bank_q[out_count];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            load_count <= '0;
            out_count <= '0;
            frame_done <= 1'b0;
        end else begin
            frame_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    load_count <= '0;
                    out_count <= '0;
                    if (frame_valid) begin
                        state <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    for (r = 0; r < M; r = r + 1) begin
                        for (c = 0; c < CP_LEN; c = c + 1) begin
                            out_lin = r * (N + CP_LEN) + c;
                            lin = r * N + (N - CP_LEN + c);
                            out_bank_i[out_lin] <= frame_i[lin / N][lin % N];
                            out_bank_q[out_lin] <= frame_q[lin / N][lin % N];
                        end
                        for (c = 0; c < N; c = c + 1) begin
                            out_lin = r * (N + CP_LEN) + CP_LEN + c;
                            lin = r * N + c;
                            out_bank_i[out_lin] <= frame_i[lin / N][lin % N];
                            out_bank_q[out_lin] <= frame_q[lin / N][lin % N];
                        end
                    end
                    state <= S_STREAM;
                end

                S_STREAM: begin
                    if (out_valid && out_ready) begin
                        if (out_count == TOTAL - 1) begin
                            out_count <= '0;
                            frame_done <= 1'b1;
                            state <= S_IDLE;
                        end else begin
                            out_count <= out_count + 1'b1;
                        end
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
