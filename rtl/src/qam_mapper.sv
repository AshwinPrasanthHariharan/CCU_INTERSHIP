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