`timescale 1ns/1ps

module tb_otfs_tx;

    localparam int M                = 4;
    localparam int N                = 4;
    localparam int CP_LEN           = 2;
    localparam int MODULATION_ORDER = 16;
    localparam int BITS_PER_SYMBOL  = 4;
    localparam int IQ_WIDTH         = 3;
    localparam int OUT_WIDTH        = IQ_WIDTH + 4;
    localparam int TOTAL_IN         = M * N;
    localparam int TOTAL_OUT        = M * (N + CP_LEN);

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

    logic isfft_out_valid;
    logic isfft_out_ready;
    logic signed [OUT_WIDTH-1:0] isfft_out_i;
    logic signed [OUT_WIDTH-1:0] isfft_out_q;
    logic busy;
    logic frame_done;

    logic cp_out_valid;
    logic cp_out_ready;
    logic signed [OUT_WIDTH-1:0] cp_out_i;
    logic signed [OUT_WIDTH-1:0] cp_out_q;
    logic cp_busy;
    logic cp_frame_done;

    logic [BITS_PER_SYMBOL-1:0] bits_mem [0:TOTAL_IN-1];
    logic signed [OUT_WIDTH-1:0] exp_i [0:TOTAL_OUT-1];
    logic signed [OUT_WIDTH-1:0] exp_q [0:TOTAL_OUT-1];
    logic signed [OUT_WIDTH-1:0] isfft_frame_i [0:M-1][0:N-1];
    logic signed [OUT_WIDTH-1:0] isfft_frame_q [0:M-1][0:N-1];

    int recv_count;
    int errors;
    int cycles;
    int load_idx;
    int isfft_idx;

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
        .out_valid(isfft_out_valid),
        .out_ready(isfft_out_ready),
        .out_i(isfft_out_i),
        .out_q(isfft_out_q),
        .busy(busy),
        .frame_done(frame_done)
    );

    cp_inserter #(
        .M(M),
        .N(N),
        .CP_LEN(CP_LEN),
        .IN_WIDTH(OUT_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) u_cp_inserter (
        .clk(clk),
        .rst_n(rst_n),
        .frame_valid(frame_done),
        .frame_i(isfft_frame_i),
        .frame_q(isfft_frame_q),
        .out_valid(cp_out_valid),
        .out_ready(cp_out_ready),
        .out_i(cp_out_i),
        .out_q(cp_out_q),
        .busy(cp_busy),
        .frame_done(cp_frame_done)
    );

    initial begin
        $readmemb("rtl/vectors/input.mem", bits_mem);
        $readmemb("rtl/vectors/ifft_cp_in_i.mem", exp_i);
        $readmemb("rtl/vectors/ifft_cp_in_q.mem", exp_q);

        bits = '0;
        in_valid = 1'b0;
        isfft_out_ready = 1'b1;
        cp_out_ready = 1'b1;
        rst_n = 1'b0;
        recv_count = 0;
        errors = 0;
        load_idx = 0;
        isfft_idx = 0;

        repeat (3) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);

        for (load_idx = 0; load_idx < TOTAL_IN; load_idx++) begin
            bits <= bits_mem[load_idx];
            in_valid <= 1'b1;
            @(posedge clk);
        end

        in_valid <= 1'b0;
        bits <= '0;

        cycles = 0;
        while (isfft_idx < TOTAL_IN && cycles < 2000) begin
            @(posedge clk);
            cycles++;

            if (isfft_out_valid && isfft_out_ready) begin
                isfft_frame_i[isfft_idx / N][isfft_idx % N] = isfft_out_i;
                isfft_frame_q[isfft_idx / N][isfft_idx % N] = isfft_out_q;
                isfft_idx++;
            end
        end

        if (isfft_idx != TOTAL_IN) begin
            $fatal(1, "FAIL: timeout waiting for ISFFT frame (got %0d/%0d).", isfft_idx, TOTAL_IN);
        end

        // Start CP insertion from the captured ISFFT frame.
        @(posedge clk);
        // frame_done is pulsed by isfft_pingpong once the frame stream is complete.

        cycles = 0;
        while (recv_count < TOTAL_OUT && cycles < 4000) begin
            @(posedge clk);
            cycles++;

            if (cp_out_valid && cp_out_ready) begin
                if ((cp_out_i !== exp_i[recv_count]) || (cp_out_q !== exp_q[recv_count])) begin
                    $display("ERR idx=%0d exp=(%0d,%0d) got=(%0d,%0d)",
                             recv_count, exp_i[recv_count], exp_q[recv_count], cp_out_i, cp_out_q);
                    errors++;
                end else begin
                    $display("OK  idx=%0d iq=(%0d,%0d)", recv_count, cp_out_i, cp_out_q);
                end
                recv_count++;
            end
        end

        if (recv_count != TOTAL_OUT) begin
            $fatal(1, "FAIL: timeout waiting for CP output stream (got %0d/%0d).", recv_count, TOTAL_OUT);
        end

        if (errors == 0) begin
            $display("PASS: OTFS TX chain matched %0d CP samples.", recv_count);
        end else begin
            $fatal(1, "FAIL: %0d mismatches in OTFS TX chain.", errors);
        end

        $finish;
    end

endmodule
