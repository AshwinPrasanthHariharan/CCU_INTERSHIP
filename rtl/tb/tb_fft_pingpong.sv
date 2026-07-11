`timescale 1ns/1ps

module tb_fft_pingpong;

    localparam int M         = 4;
    localparam int N         = 4;
    localparam int IQ_WIDTH  = 3;
    localparam int OUT_WIDTH = IQ_WIDTH + 4;
    localparam int TOTAL     = M * N;

    logic clk;
    logic rst_n;

    logic frame_valid;
    logic signed [OUT_WIDTH-1:0] frame_i [0:M-1][0:N-1];
    logic signed [OUT_WIDTH-1:0] frame_q [0:M-1][0:N-1];

    logic signed [OUT_WIDTH-1:0] time_i [0:M-1][0:N-1];
    logic signed [OUT_WIDTH-1:0] time_q [0:M-1][0:N-1];
    logic frame_done;

    logic signed [OUT_WIDTH-1:0] in_i_mem [0:TOTAL-1];
    logic signed [OUT_WIDTH-1:0] in_q_mem [0:TOTAL-1];
    logic signed [OUT_WIDTH-1:0] exp_i [0:TOTAL-1];
    logic signed [OUT_WIDTH-1:0] exp_q [0:TOTAL-1];

    int errors;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    fft_pingpong #(
        .M(M),
        .N(N),
        .IQ_WIDTH(IQ_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) u_fft_pingpong (
        .clk(clk),
        .rst_n(rst_n),
        .frame_valid(frame_valid),
        .frame_i(frame_i),
        .frame_q(frame_q),
        .time_i(time_i),
        .time_q(time_q),
        .busy(),
        .frame_done(frame_done)
    );

    initial begin
        $readmemb("rtl/vectors/ifft_pingpong_exp_i.mem", in_i_mem);
        $readmemb("rtl/vectors/ifft_pingpong_exp_q.mem", in_q_mem);
        $readmemb("rtl/vectors/isfft_exp_i.mem", exp_i);
        $readmemb("rtl/vectors/isfft_exp_q.mem", exp_q);

        for (int sample_idx = 0; sample_idx < TOTAL; sample_idx++) begin
            int row_idx;
            int col_idx;

            row_idx = sample_idx / N;
            col_idx = sample_idx % N;
            frame_i[row_idx][col_idx] = in_i_mem[sample_idx];
            frame_q[row_idx][col_idx] = in_q_mem[sample_idx];
        end

        errors = 0;
        rst_n = 1'b0;
        frame_valid = 1'b0;

        repeat (3) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);

        frame_valid <= 1'b1;
        @(posedge clk);
        frame_valid <= 1'b0;

        while (frame_done !== 1'b1) begin
            @(posedge clk);
        end

        @(posedge clk);

        for (int sample_idx = 0; sample_idx < TOTAL; sample_idx++) begin
            int row_idx;
            int col_idx;

            row_idx = sample_idx / N;
            col_idx = sample_idx % N;

            if ((time_i[row_idx][col_idx] !== exp_i[sample_idx]) || (time_q[row_idx][col_idx] !== exp_q[sample_idx])) begin
                $display("ERR idx=%0d exp=(%0d,%0d) got=(%0d,%0d)",
                         sample_idx, exp_i[sample_idx], exp_q[sample_idx], time_i[row_idx][col_idx], time_q[row_idx][col_idx]);
                errors++;
            end else begin
                $display("OK  idx=%0d iq=(%0d,%0d)", sample_idx, time_i[row_idx][col_idx], time_q[row_idx][col_idx]);
            end
        end

        if (errors == 0) begin
            $display("PASS: FFT ping-pong matched %0d samples.", TOTAL);
        end else begin
            $fatal(1, "FAIL: %0d mismatches in FFT ping-pong test.", errors);
        end

        $finish;
    end

endmodule
