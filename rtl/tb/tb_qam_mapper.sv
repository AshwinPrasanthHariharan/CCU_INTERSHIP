`timescale 1ns/1ps

module tb_qam_mapper;

    localparam int NUM_SYMS = 16;

    logic [3:0] bits_mem [0:NUM_SYMS-1];
    logic [3:0] bits;

    logic signed [2:0] i;
    logic signed [2:0] q;

    logic signed [2:0] exp_i [0:NUM_SYMS-1];
    logic signed [2:0] exp_q [0:NUM_SYMS-1];
    int errors = 0;

    qam_mapper dut(
        .bits(bits),
        .i(i),
        .q(q)
    );

    initial begin
        $readmemb("rtl/vectors/bitsstream.mem", bits_mem);
        $readmemb("rtl/vectors/exp_i.mem", exp_i);
        $readmemb("rtl/vectors/exp_q.mem", exp_q);

        for (int k = 0; k < NUM_SYMS; k++) begin
            bits = bits_mem[k];
            #1;

            if ((i !== exp_i[k]) || (q !== exp_q[k])) begin
                $display("ERR k=%0d bits=%b exp=(%0d,%0d) got=(%0d,%0d)",
                         k, bits, exp_i[k], exp_q[k], i, q);
                errors++;
            end else begin
                $display("OK  k=%0d bits=%b iq=(%0d,%0d)", k, bits, i, q);
            end
        end

        if (errors == 0) begin
            $display("PASS: all %0d symbols matched.", NUM_SYMS);
        end else begin
            $fatal(1, "FAIL: %0d mismatches out of %0d symbols.", errors, NUM_SYMS);
        end

        $finish;
    end

endmodule