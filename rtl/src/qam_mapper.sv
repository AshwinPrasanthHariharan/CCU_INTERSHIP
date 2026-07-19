//------------------------------------------------------------------------------
// Module      : qam_mapper
//
// Purpose:
//   - Combinational wrapper that maps a BITS_PER_SYMBOL wide input nibble into
//     fixed-width signed I/Q outputs using a read-only constellation ROM
//     (`constellation_rom`). This module exposes parameterizable modulation
//     order and IQ bit-width for use across testbenches and RTL chains.
//
// Behavior / Algorithm:
//   1. Treat the input `bits` as the ROM address and forward it to the
//      instantiated `constellation_rom` instance.
//   2. The ROM outputs signed `i` and `q` values (width `IQ_WIDTH`) which are
//      presented combinationally on the module outputs.
//
// Notes:
//   - Mapping is purely combinational and has no internal state; timing is
//     determined by downstream registers. See `rtl/src/constellation.sv` for
//     the Gray-coded mapping table used by the ROM.
//------------------------------------------------------------------------------
module qam_mapper #(
    parameter int MODULATION_ORDER = 16,
    parameter int IQ_WIDTH         = 3, // rt(MODULATION_ORDER) -1
    parameter int BITS_PER_SYMBOL  = 4 //$clog2(MODULATION_ORDER)
)(
    input  logic [BITS_PER_SYMBOL-1:0] bits,

    output logic signed [IQ_WIDTH-1:0] i,
    output logic signed [IQ_WIDTH-1:0] q
);

    constellation_rom #(
        .MODULATION_ORDER(MODULATION_ORDER),
        .IQ_WIDTH(IQ_WIDTH)
    ) ROM (
        .addr(bits),
        .i(i),
        .q(q)
    );

endmodule