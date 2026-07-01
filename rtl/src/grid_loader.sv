//------------------------------------------------------------------------------
// Module      : grid_loader
//
// Stores incoming QAM I/Q symbols into an MxN delay-Doppler grid in row-major
// order. Asserts grid_valid once the full frame is loaded.
//------------------------------------------------------------------------------
module grid_loader #(
    parameter int M        = 4,
    parameter int N        = 4,
    parameter int IQ_WIDTH = 3
)(
    input  logic clk,
    input  logic rst_n,

    // Assert for one cycle to start loading a new frame.
    input  logic frame_start,

    // Input symbol stream from mapper.
    input  logic in_valid,
    input  logic signed [IQ_WIDTH-1:0] in_i,
    input  logic signed [IQ_WIDTH-1:0] in_q,

    // High when all M*N symbols are written.
    output logic grid_valid,

    // Optional debug visibility of current write position.
    output logic [$clog2(M)-1:0] wr_row,
    output logic [$clog2(N)-1:0] wr_col,

    // Stored delay-Doppler grid.
    output logic signed [IQ_WIDTH-1:0] grid_i [0:M-1][0:N-1],
    output logic signed [IQ_WIDTH-1:0] grid_q [0:M-1][0:N-1]
);

    localparam int TOTAL_SYMS = M * N;
    localparam int COUNT_W    = (TOTAL_SYMS <= 1) ? 1 : $clog2(TOTAL_SYMS + 1);

    logic [COUNT_W-1:0] sym_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_row    <= '0;
            wr_col    <= '0;
            sym_count <= '0;
            grid_valid <= 1'b0;
        end else if (frame_start) begin
            wr_row    <= '0;
            wr_col    <= '0;
            sym_count <= '0;
            grid_valid <= 1'b0;
        end else if (in_valid && !grid_valid) begin
            // Store incoming symbol at current write pointer.
            grid_i[wr_row][wr_col] <= in_i;
            grid_q[wr_row][wr_col] <= in_q;

            // Update counters/pointers.
            sym_count <= sym_count + 1'b1;

            if (sym_count == TOTAL_SYMS - 1) begin
                grid_valid <= 1'b1;
            end else if (wr_col == N - 1) begin
                wr_col <= '0;
                wr_row <= wr_row + 1'b1;
            end else begin
                wr_col <= wr_col + 1'b1;
            end
        end
    end

endmodule
