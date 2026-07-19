//------------------------------------------------------------------------------
// Module      : cp_remover
//
// Purpose:
//   - Remove the cyclic prefix from incoming M x (N+CP_LEN) frames and
//     restore the original M x N payload grid for downstream FFT/ISFFT
//     processing in the receiver chain.
//
// Behavior / Algorithm:
//   1. When `frame_valid` is asserted, for each row r copy samples
//      `frame_i[r][CP_LEN + c]` / `frame_q[r][CP_LEN + c]` for c=0..N-1 into
//      the compact output arrays `out_i[r][c]` and `out_q[r][c]`.
//   2. Assert `out_valid` while the payload grid is presented and signal
//      `frame_done` once downstream modules acknowledge the data via
//      `out_ready` and the transfer completes.
//
// Notes:
//   - This module is a deterministic buffer extractor; it assumes valid
//     framing and does not perform timing recovery or synchronization.
//------------------------------------------------------------------------------
module cp_remover #(
    parameter int M         = 4,
    parameter int N         = 4,
    parameter int CP_LEN    = 2,
    parameter int IN_WIDTH  = 7,
    parameter int OUT_WIDTH = IN_WIDTH
)(
    input  logic clk,
    input  logic rst_n,

    input  logic frame_valid,
    input  logic signed [IN_WIDTH-1:0] frame_i [0:M-1][0:N+CP_LEN-1],
    input  logic signed [IN_WIDTH-1:0] frame_q [0:M-1][0:N+CP_LEN-1],

    output logic out_valid,
    input  logic out_ready,
    output logic signed [OUT_WIDTH-1:0] out_i [0:M-1][0:N-1],
    output logic signed [OUT_WIDTH-1:0] out_q [0:M-1][0:N-1],
    output logic busy,
    output logic frame_done
);

    typedef enum logic [0:0] {
        S_IDLE,
        S_LOAD
    } state_t;

    state_t state;

    integer r;
    integer c;

    assign busy = (state != S_IDLE);
    assign out_valid = (state == S_LOAD);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            frame_done <= 1'b0;
        end else begin
            frame_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (frame_valid) begin
                        for (r = 0; r < M; r = r + 1) begin
                            for (c = 0; c < N; c = c + 1) begin
                                out_i[r][c] <= frame_i[r][CP_LEN + c];
                                out_q[r][c] <= frame_q[r][CP_LEN + c];
                            end
                        end
                        state <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    if (out_ready) begin
                        frame_done <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule