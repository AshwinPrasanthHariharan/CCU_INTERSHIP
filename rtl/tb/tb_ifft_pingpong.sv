`timescale 1ns/1ps

module tb_ifft_pingpong;

    localparam int M                = 4;
    localparam int N                = 4;
    localparam int MODULATION_ORDER = 16;
    localparam int BITS_PER_SYMBOL  = 4;
    localparam int IQ_WIDTH         = 3;
    localparam int OUT_WIDTH        = IQ_WIDTH + 4;
    localparam int TOTAL            = M * N;

    logic clk;
    logic rst_n;

    logic in_valid;
    logic [BITS_PER_SYMBOL-1:0] bits;

    logic signed [IQ_WIDTH-1:0] map_i;
    logic signed [IQ_WIDTH-1:0] map_q;

    logic grid_valid;
    logic frame_start;
    logic [$clog2(M)-1:0] wr_row;
    logic [$clog2(N)-1:0] wr_col;
    logic signed [IQ_WIDTH-1:0] grid_i [0:M-1][0:N-1];
    logic signed [IQ_WIDTH-1:0] grid_q [0:M-1][0:N-1];

    logic tf_valid;
    logic tf_ready;
    logic signed [OUT_WIDTH-1:0] tf_out_i;
    logic signed [OUT_WIDTH-1:0] tf_out_q;
    logic tf_busy;
    logic tf_frame_done;

    logic ifft_frame_valid;
    logic signed [OUT_WIDTH-1:0] time_i [0:M-1][0:N-1];
    logic signed [OUT_WIDTH-1:0] time_q [0:M-1][0:N-1];
    logic ifft_busy;
    logic ifft_frame_done;

    logic [BITS_PER_SYMBOL-1:0] bits_mem [0:TOTAL-1];
    logic signed [OUT_WIDTH-1:0] exp_i [0:TOTAL-1];
    logic signed [OUT_WIDTH-1:0] exp_q [0:TOTAL-1];

    logic signed [OUT_WIDTH-1:0] tf_frame_i [0:M-1][0:N-1];
    logic signed [OUT_WIDTH-1:0] tf_frame_q [0:M-1][0:N-1];

    int recv_count;
    int tf_count;
    int errors;
    int cycles;
    int load_idx;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    qam_mapper #(
        .MODULATION_ORDER(MODULATION_ORDER),
        .IQ_WIDTH(IQ_WIDTH),
        .BITS_PER_SYMBOL(BITS_PER_SYMBOL)
    ) u_qam_mapper (
        .bits(bits),
        .i(map_i),
        .q(map_q)
    );

    grid_loader #(
        .M(M),
        .N(N),
        .IQ_WIDTH(IQ_WIDTH)
    ) u_grid_loader (
        .clk(clk),
        .rst_n(rst_n),
        .frame_start(frame_start),
        .in_valid(in_valid),
        .in_i(map_i),
        .in_q(map_q),
        .grid_valid(grid_valid),
        .wr_row(wr_row),
        .wr_col(wr_col),
        .grid_i(grid_i),
        .grid_q(grid_q)
    );

    isfft_pingpong #(
        .M(M),
        .N(N),
        .IQ_WIDTH(IQ_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) u_isfft_pingpong (
        .clk(clk),
        .rst_n(rst_n),
        .grid_valid(grid_valid),
        .grid_i(grid_i),
        .grid_q(grid_q),
        .frame_start(frame_start),
        .out_valid(tf_valid),
        .out_ready(tf_ready),
        .out_i(tf_out_i),
        .out_q(tf_out_q),
        .busy(tf_busy),
        .frame_done(tf_frame_done)
    );

    ifft_pingpong #(
        .M(M),
        .N(N),
        .IQ_WIDTH(IQ_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) u_ifft_pingpong (
        .clk(clk),
        .rst_n(rst_n),
        .frame_valid(ifft_frame_valid),
        .frame_i(tf_frame_i),
        .frame_q(tf_frame_q),
        .time_i(time_i),
        .time_q(time_q),
        .busy(ifft_busy),
        .frame_done(ifft_frame_done)
    );

    initial begin
        $readmemb("rtl/vectors/input.mem", bits_mem);
        $readmemb("rtl/vectors/ifft_pingpong_exp_i.mem", exp_i);
        $readmemb("rtl/vectors/ifft_pingpong_exp_q.mem", exp_q);

        bits = '0;
        in_valid = 1'b0;
        tf_ready = 1'b1;
        ifft_frame_valid = 1'b0;
        rst_n = 1'b0;
        recv_count = 0;
        tf_count = 0;
        errors = 0;
        load_idx = 0;

        repeat (3) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);

        for (load_idx = 0; load_idx < TOTAL; load_idx++) begin
            bits <= bits_mem[load_idx];
            in_valid <= 1'b1;
            @(posedge clk);
        end

        in_valid <= 1'b0;
        bits <= '0;

        cycles = 0;
        while (tf_count < TOTAL && cycles < 2000) begin
            @(posedge clk);
            cycles++;

            if (tf_valid && tf_ready) begin
                tf_frame_i[tf_count / N][tf_count % N] = tf_out_i;
                tf_frame_q[tf_count / N][tf_count % N] = tf_out_q;
                tf_count++;
            end
        end

        if (tf_count != TOTAL) begin
            $fatal(1, "FAIL: timeout waiting for ISFFT output (got %0d/%0d).", tf_count, TOTAL);
        end

        @(posedge clk);
        ifft_frame_valid <= 1'b1;
        @(posedge clk);
        ifft_frame_valid <= 1'b0;

        // Allow the combinational-array output to settle after the IFFT pulse.
        @(posedge clk);

        for (int idx = 0; idx < TOTAL; idx++) begin
            int r;
            int c;

            r = idx / N;
            c = idx % N;

            if ((time_i[r][c] !== exp_i[idx]) || (time_q[r][c] !== exp_q[idx])) begin
                $display("ERR idx=%0d exp=(%0d,%0d) got=(%0d,%0d)",
                         idx, exp_i[idx], exp_q[idx], time_i[r][c], time_q[r][c]);
                errors++;
            end else begin
                $display("OK  idx=%0d iq=(%0d,%0d)", idx, time_i[r][c], time_q[r][c]);
            end
        end

        if (errors == 0) begin
            $display("PASS: standalone IFFT ping-pong matched %0d samples.", TOTAL);
        end else begin
            $fatal(1, "FAIL: %0d mismatches in standalone IFFT ping-pong test.", errors);
        end

        $finish;
    end

endmodule