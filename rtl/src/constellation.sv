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