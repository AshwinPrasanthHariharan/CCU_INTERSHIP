`timescale 1ns/1ps

module tb_isfft_chain;

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

    logic out_valid;
    logic out_ready;
    logic signed [OUT_WIDTH-1:0] out_i;
    logic signed [OUT_WIDTH-1:0] out_q;
    logic busy;
    logic frame_done;

    logic [BITS_PER_SYMBOL-1:0] bits_mem [0:TOTAL-1];

    logic signed [OUT_WIDTH-1:0] exp_i [0:TOTAL-1];
    logic signed [OUT_WIDTH-1:0] exp_q [0:TOTAL-1];

    int rd_ptr;
    int recv_count;
    int errors;
    int cycles;

    string input_mem_file;
    string exp_i_mem_file;
    string exp_q_mem_file;

    // 100 MHz clock
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
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_i(out_i),
        .out_q(out_q),
        .busy(busy),
        .frame_done(frame_done)
    );

    initial begin
        if (!$value$plusargs("INPUT_MEM=%s", input_mem_file)) begin
            input_mem_file = "rtl/vectors/input.mem";
        end
        if (!$value$plusargs("EXP_I_MEM=%s", exp_i_mem_file)) begin
            exp_i_mem_file = "rtl/vectors/ifft_exp_i.mem";
        end
        if (!$value$plusargs("EXP_Q_MEM=%s", exp_q_mem_file)) begin
            exp_q_mem_file = "rtl/vectors/ifft_exp_q.mem";
        end

        $display("[TB] Reading input symbols from: %s", input_mem_file);
        $display("[TB] Reading expected I from:   %s", exp_i_mem_file);
        $display("[TB] Reading expected Q from:   %s", exp_q_mem_file);
        $readmemb(input_mem_file, bits_mem);
        $readmemb(exp_i_mem_file, exp_i);
        $readmemb(exp_q_mem_file, exp_q);

        bits = '0;
        in_valid = 1'b0;
        out_ready = 1'b1;
        rst_n = 1'b0;

        rd_ptr = 0;
        recv_count = 0;
        errors = 0;

        // Reset
        repeat (3) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);

        // Stream one frame from input.mem.
        // Expected post-ISFFT values are precomputed in ifft_exp_i/q.mem.
        for (int k = 0; k < TOTAL; k++) begin
            bits <= bits_mem[k];
            in_valid <= 1'b1;

            @(posedge clk);
        end

        in_valid <= 1'b0;
        bits <= '0;

        // Receive/check one frame
        cycles = 0;
        while (recv_count < TOTAL && cycles < 2000) begin
            @(posedge clk);
            cycles++;

            if (out_valid && out_ready) begin
                if ((out_i !== exp_i[rd_ptr]) || (out_q !== exp_q[rd_ptr])) begin
                    $display("ERR idx=%0d exp=(%0d,%0d) got=(%0d,%0d)",
                             rd_ptr, exp_i[rd_ptr], exp_q[rd_ptr], out_i, out_q);
                    errors++;
                end else begin
                    $display("OK  idx=%0d iq=(%0d,%0d)", rd_ptr, out_i, out_q);
                end
                rd_ptr++;
                recv_count++;
            end
        end

        if (recv_count != TOTAL) begin
            $fatal(1, "FAIL: timeout waiting for output stream (got %0d/%0d).", recv_count, TOTAL);
        end

        if (!frame_done) begin
            // frame_done is a pulse; allow one extra cycle for visibility.
            @(posedge clk);
        end

        if (errors == 0) begin
            $display("PASS: combined chain matched %0d/%0d samples.", recv_count, TOTAL);
        end else begin
            $fatal(1, "FAIL: %0d mismatches in combined chain.", errors);
        end

        $finish;
    end

endmodule
