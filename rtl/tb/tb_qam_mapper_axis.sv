`timescale 1ns/1ps

module tb_qam_mapper_axis;

    localparam int NUM_BITS = 32;

    logic clk;
    logic rst_n;
    logic in_valid;
    logic [1:0] bits_mem [0:NUM_BITS-1];
    logic [1:0] bits;

    logic signed [2:0] axis_value;
    logic axis_is_q;
    logic out_valid;
    logic symbol_done;

    int errors = 0;

    localparam string INPUT_MEM = "rtl/vectors/input2b.mem";

    qam_mapper_axis dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .bits(bits),
        .axis_value(axis_value),
        .axis_is_q(axis_is_q),
        .out_valid(out_valid),
        .symbol_done(symbol_done)
    );

    function automatic logic signed [2:0] expected_axis_value(
        input logic [1:0] sym_bits
    );
        case (sym_bits)
            2'b00: expected_axis_value = -1;
            2'b01: expected_axis_value = -1;
            2'b11: expected_axis_value =  1;
            2'b10: expected_axis_value =  1;
            default: expected_axis_value = '0;
        endcase
    endfunction

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        in_valid = 1'b0;
        bits = '0;

        $readmemb(INPUT_MEM, bits_mem);

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        for (int k = 0; k < NUM_BITS; k++) begin
            bits <= bits_mem[k];
            in_valid <= 1'b1;
            @(posedge clk);
            #1;

            if (!out_valid) begin
                $display("ERR k=%0d expected valid pulse", k);
                errors++;
            end else if (axis_value !== expected_axis_value(bits_mem[k])) begin
                $display("ERR k=%0d bits=%b exp=%0d got=%0d axis=%s",
                         k, bits_mem[k], expected_axis_value(bits_mem[k]), axis_value,
                         axis_is_q ? "Q" : "I");
                errors++;
            end else begin
                $display("OK  k=%0d axis=%s bits=%b value=%0d%s",
                         k,
                         axis_is_q ? "Q" : "I",
                         bits_mem[k],
                         axis_value,
                         symbol_done ? " symbol_done" : "");
            end
        end

        in_valid <= 1'b0;
        @(posedge clk);

        if (errors == 0) begin
            $display("PASS: all %0d axis samples matched.", NUM_BITS);
        end else begin
            $fatal(1, "FAIL: %0d mismatches out of %0d axis samples.", errors, NUM_BITS);
        end

        $finish;
    end

endmodule