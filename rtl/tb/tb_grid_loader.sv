`timescale 1ns/1ps

module tb_grid_loader;

    localparam int M              = 4;
    localparam int N              = 4;
    localparam int MODULATION_ORDER = 16;
    localparam int BITS_PER_SYMBOL  = 4;
    localparam int IQ_WIDTH         = 3;
    localparam int NUM_SYMS         = M * N;

    logic clk;
    logic rst_n;
    logic frame_start;
    logic in_valid;

    logic [BITS_PER_SYMBOL-1:0] bits;
    logic [BITS_PER_SYMBOL-1:0] bits_mem [0:NUM_SYMS-1];

    logic signed [IQ_WIDTH-1:0] map_i;
    logic signed [IQ_WIDTH-1:0] map_q;

    logic grid_valid;
    logic [$clog2(M)-1:0] wr_row;
    logic [$clog2(N)-1:0] wr_col;
    logic signed [IQ_WIDTH-1:0] grid_i [0:M-1][0:N-1];
    logic signed [IQ_WIDTH-1:0] grid_q [0:M-1][0:N-1];

    int errors;

    // Reuse existing mapper (which instantiates constellation_rom internally).
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

    // 100 MHz clock (10 ns period)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        errors = 0;
        bits = '0;
        rst_n = 1'b0;
        frame_start = 1'b0;
        in_valid = 1'b0;

        $readmemb("input.mem", bits_mem);

        // Reset and start a new frame.
        repeat (2) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
        frame_start <= 1'b1;
        @(posedge clk);
        frame_start <= 1'b0;

        // Stream one symbol per cycle from input.mem.
        for (int k = 0; k < NUM_SYMS; k++) begin
            int exp_row;
            int exp_col;

            exp_row = k / N;
            exp_col = k % N;

            bits <= bits_mem[k];
            in_valid <= 1'b1;

            // Self-traversal verification: current write pointer must match
            // row-major location for the symbol being presented this cycle.
            #1;
            if ((wr_row !== exp_row[$clog2(M)-1:0]) || (wr_col !== exp_col[$clog2(N)-1:0])) begin
                $display("ERR PTR k=%0d exp_ptr=(%0d,%0d) got_ptr=(%0d,%0d)",
                         k, exp_row, exp_col, wr_row, wr_col);
                errors++;
            end

            @(posedge clk);
        end
        in_valid <= 1'b0;

        // Let state settle and then check frame complete.
        @(posedge clk);
        if (grid_valid !== 1'b1) begin
            $display("ERR: grid_valid not asserted after %0d symbols", NUM_SYMS);
            errors++;
        end

        // Once full, loader must stop advancing pointers and stop writing.
        if ((wr_row !== M-1) || (wr_col !== N-1)) begin
            $display("ERR: pointer not held at final cell after full grid, got (%0d,%0d)", wr_row, wr_col);
            errors++;
        end

        // Try one extra valid cycle and ensure pointer does not move.
        bits <= bits_mem[0];
        in_valid <= 1'b1;
        @(posedge clk);
        in_valid <= 1'b0;
        if ((wr_row !== M-1) || (wr_col !== N-1)) begin
            $display("ERR: pointer moved after grid_valid asserted, got (%0d,%0d)", wr_row, wr_col);
            errors++;
        end

        // Validate grid contents in row-major order against current mapper output.
        for (int idx = 0; idx < NUM_SYMS; idx++) begin
            int r;
            int c;
            logic signed [IQ_WIDTH-1:0] exp_i;
            logic signed [IQ_WIDTH-1:0] exp_q;

            r = idx / N;
            c = idx % N;

            bits = bits_mem[idx];
            #1; // combinational settle through qam_mapper
            exp_i = map_i;
            exp_q = map_q;

            if ((grid_i[r][c] !== exp_i) || (grid_q[r][c] !== exp_q)) begin
                $display("ERR idx=%0d rc=(%0d,%0d) bits=%b exp=(%0d,%0d) got=(%0d,%0d)",
                         idx, r, c, bits_mem[idx], exp_i, exp_q, grid_i[r][c], grid_q[r][c]);
                errors++;
            end else begin
                $display("OK  idx=%0d rc=(%0d,%0d) bits=%b iq=(%0d,%0d)",
                         idx, r, c, bits_mem[idx], grid_i[r][c], grid_q[r][c]);
            end
        end

        if (errors == 0) begin
            $display("PASS: grid_loader stored all %0d symbols correctly.", NUM_SYMS);
        end else begin
            $fatal(1, "FAIL: %0d mismatches in grid_loader test.", errors);
        end

        $finish;
    end

endmodule
