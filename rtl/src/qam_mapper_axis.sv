//------------------------------------------------------------------------------
// Module      : qam_mapper_axis
//
// Purpose:
//   - Streaming, per-axis symbol mapper that accepts two-bit symbol halves on
//     a simple valid handshake and emits successive I and Q axis samples.
//   - Designed for simple axis-style upstream interfaces where each nibble is
//     provided as two sequential 2-bit symbols (I then Q) and `symbol_done`
//     flags the completion of a full complex symbol.
//
// Behavior / Algorithm:
//   1. On each `in_valid` cycle, call `map_axis_bits()` to convert the
//      incoming 2-bit group into a signed axis level.
//   2. Alternate between I and Q outputs using `next_axis_is_q`. The first
//      2-bit group for a symbol is emitted as I, the second as Q; when Q is
//      emitted `symbol_done` is asserted for one cycle.
//   3. `pending_i` and `pending_q` store the most recently received I/Q
//      halves for optional debugging or downstream synchronization.
//
// Notes:
//   - Mapping function `map_axis_bits` implements a reduced-level mapping used
//     for axis test flows (see `rtl/src/qam_mapper.sv` for full nibble ROM
//     mapping).
//------------------------------------------------------------------------------
module qam_mapper_axis #(
    parameter int IQ_WIDTH = 3
)(
    input  logic clk,
    input  logic rst_n,
    input  logic in_valid,
    input  logic [1:0] bits,

    output logic signed [IQ_WIDTH-1:0] axis_value,
    output logic axis_is_q,
    output logic out_valid,
    output logic symbol_done
);

    logic next_axis_is_q;
    logic signed [IQ_WIDTH-1:0] pending_i;
    logic signed [IQ_WIDTH-1:0] pending_q;

    function automatic logic signed [IQ_WIDTH-1:0] map_axis_bits(
        input logic [1:0] sym_bits
    );
        case (sym_bits)
            2'b00: map_axis_bits = -1;
            2'b01: map_axis_bits = -1;
            2'b11: map_axis_bits =  1;
            2'b10: map_axis_bits =  1;
            default: map_axis_bits = '0;
        endcase
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axis_value     <= '0;
            axis_is_q      <= 1'b0;
            out_valid      <= 1'b0;
            symbol_done    <= 1'b0;
            next_axis_is_q <= 1'b0;
            pending_i      <= '0;
            pending_q      <= '0;
        end else begin
            out_valid   <= 1'b0;
            symbol_done <= 1'b0;

            if (in_valid) begin
                if (!next_axis_is_q) begin
                    pending_i   <= map_axis_bits(bits);
                    axis_value  <= map_axis_bits(bits);
                    axis_is_q   <= 1'b0;
                    out_valid   <= 1'b1;
                end else begin
                    pending_q   <= map_axis_bits(bits);
                    axis_value  <= map_axis_bits(bits);
                    axis_is_q   <= 1'b1;
                    out_valid   <= 1'b1;
                    symbol_done <= 1'b1;
                end

                next_axis_is_q <= ~next_axis_is_q;
            end
        end
    end

endmodule