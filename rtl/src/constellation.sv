//------------------------------------------------------------------------------
// Module      : constellation_rom
//
// Purpose:
//   - Provide a parameterized, Gray-coded constellation lookup for several
//     modulation orders (e.g., QPSK/4-QAM, 16-QAM). The ROM converts the
//     incoming symbol address `addr` into fixed integer I/Q coordinates used
//     by the RTL QAM mapping modules.
//
// Behavior / Algorithm:
//   - Implemented as an `always_comb` case-statement that selects I/Q integer
//     coordinates based on `MODULATION_ORDER` and `addr`.
//   - For 16-QAM the mapping follows a Gray-coded arrangement returning
//     integer levels {-3,-1,1,3} (scaled to `IQ_WIDTH`). For smaller orders
//     the mapping reduces to appropriate QAM points.
//
// Notes:
//   - Outputs are signed integers sized to `IQ_WIDTH` and intended to be used
//     directly by downstream fixed-point datapaths. Adjust `IQ_WIDTH` to
//     change the representable range.
//------------------------------------------------------------------------------
module constellation_rom #(
    parameter int MODULATION_ORDER = 16,
    parameter int IQ_WIDTH = 3
)(
    input  logic [$clog2(MODULATION_ORDER)-1:0] addr,

    output logic signed [IQ_WIDTH-1:0] i,
    output logic signed [IQ_WIDTH-1:0] q
);

always_comb begin

    i = '0;
    q = '0;

    case (MODULATION_ORDER)

        4: begin

            case(addr)

                2'b00: begin i=-1; q=-1; end
                2'b01: begin i=-1; q= 1; end
                2'b11: begin i= 1; q= 1; end
                2'b10: begin i= 1; q=-1; end

            endcase

        end

        16: begin

            case(addr)

                4'b0000: begin i=-3; q=-3; end
                4'b0001: begin i=-3; q=-1; end
                4'b0011: begin i=-3; q= 1; end
                4'b0010: begin i=-3; q= 3; end

                4'b0100: begin i=-1; q=-3; end
                4'b0101: begin i=-1; q=-1; end
                4'b0111: begin i=-1; q= 1; end
                4'b0110: begin i=-1; q= 3; end

                4'b1100: begin i= 1; q=-3; end
                4'b1101: begin i= 1; q=-1; end
                4'b1111: begin i= 1; q= 1; end
                4'b1110: begin i= 1; q= 3; end

                4'b1000: begin i= 3; q=-3; end
                4'b1001: begin i= 3; q=-1; end
                4'b1011: begin i= 3; q= 1; end
                4'b1010: begin i= 3; q= 3; end

            endcase

        end

        default: begin
            i='0;
            q='0;
        end

    endcase

end

endmodule