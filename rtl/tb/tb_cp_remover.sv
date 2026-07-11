`timescale 1ns/1ps

module tb_cp_remover;

    localparam int M                = 4;
    localparam int N                = 4;
    localparam int CP_LEN           = 2;
    localparam int IN_WIDTH         = 7;
    localparam int OUT_WIDTH        = IN_WIDTH;
    localparam int TOTAL_IN         = M * (N + CP_LEN);
    localparam int TOTAL_OUT        = M * N;

    logic clk;
    logic rst_n;

    logic frame_valid;
    logic out_ready;
    logic out_valid;
    logic busy;
    logic frame_done;

    logic signed [IN_WIDTH-1:0] frame_i [0:M-1][0:N+CP_LEN-1];
    logic signed [IN_WIDTH-1:0] frame_q [0:M-1][0:N+CP_LEN-1];
    logic signed [OUT_WIDTH-1:0] out_i [0:M-1][0:N-1];
    logic signed [OUT_WIDTH-1:0] out_q [0:M-1][0:N-1];

    logic signed [IN_WIDTH-1:0] in_i_mem [0:TOTAL_IN-1];
    logic signed [IN_WIDTH-1:0] in_q_mem [0:TOTAL_IN-1];
    logic signed [OUT_WIDTH-1:0] exp_i [0:TOTAL_OUT-1];
    logic signed [OUT_WIDTH-1:0] exp_q [0:TOTAL_OUT-1];

    int errors;
    int idx;
    int r;
    int c;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    cp_remover #(
        .M(M),
        .N(N),
        .CP_LEN(CP_LEN),
        .IN_WIDTH(IN_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) u_cp_remover (
        .clk(clk),
        .rst_n(rst_n),
        .frame_valid(frame_valid),
        .frame_i(frame_i),
        .frame_q(frame_q),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_i(out_i),
        .out_q(out_q),
        .busy(busy),
        .frame_done(frame_done)
    );

    initial begin
        $readmemb("rtl/vectors/ifft_cp_in_i.mem", in_i_mem);
        $readmemb("rtl/vectors/ifft_cp_in_q.mem", in_q_mem);
        $readmemb("rtl/vectors/ifft_pingpong_exp_i.mem", exp_i);
        $readmemb("rtl/vectors/ifft_pingpong_exp_q.mem", exp_q);

        for (idx = 0; idx < TOTAL_IN; idx++) begin
            r = idx / (N + CP_LEN);
            c = idx % (N + CP_LEN);
            frame_i[r][c] = in_i_mem[idx];
            frame_q[r][c] = in_q_mem[idx];
        end

        errors = 0;
        frame_valid = 1'b0;
        out_ready = 1'b1;
        rst_n = 1'b0;

        repeat (3) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);

        frame_valid <= 1'b1;
        @(posedge clk);
        frame_valid <= 1'b0;

        while (frame_done !== 1'b1) begin
            @(posedge clk);
        end

        for (idx = 0; idx < TOTAL_OUT; idx++) begin
            r = idx / N;
            c = idx % N;

            if ((out_i[r][c] !== exp_i[idx]) || (out_q[r][c] !== exp_q[idx])) begin
                $display("ERR idx=%0d exp=(%0d,%0d) got=(%0d,%0d)",
                         idx, exp_i[idx], exp_q[idx], out_i[r][c], out_q[r][c]);
                errors++;
            end else begin
                $display("OK  idx=%0d iq=(%0d,%0d)", idx, out_i[r][c], out_q[r][c]);
            end
        end

        if (errors == 0) begin
            $display("PASS: CP remover matched %0d payload samples.", TOTAL_OUT);
        end else begin
            $fatal(1, "FAIL: %0d mismatches in CP remover test.", errors);
        end

        $finish;
    end

endmodule