module isfft_pingpong #(
    parameter int M         = 4,
    parameter int N         = 4,
    parameter int IQ_WIDTH  = 3,
    parameter int OUT_WIDTH = IQ_WIDTH + 4
)(
    input  logic clk,
    input  logic rst_n,

    // Grid-loader interface
    input  logic grid_valid,
    input  logic signed [IQ_WIDTH-1:0] grid_i [0:M-1][0:N-1],
    input  logic signed [IQ_WIDTH-1:0] grid_q [0:M-1][0:N-1],
    output logic frame_start,

    // Streamed output frame (post-ISFFT)
    output logic out_valid,
    input  logic out_ready,
    output logic signed [OUT_WIDTH-1:0] out_i,
    output logic signed [OUT_WIDTH-1:0] out_q,

    // Status
    output logic busy,
    output logic frame_done
);

    localparam int TOTAL = M * N;
    localparam int IDX_W = (TOTAL <= 1) ? 1 : $clog2(TOTAL);
    localparam int MAX_FFT = 64;
    localparam int TW_W    = 12;
    localparam int TW_FRAC = TW_W - 2;
    localparam real PI_R   = 3.14159265358979323846;

    typedef enum logic [1:0] {
        S_IDLE,
        S_ROW_PASS,
        S_COL_PASS,
        S_STREAM
    } state_t;

    state_t state;

    logic cap_bank_sel;
    logic proc_bank_sel;
    logic bank_full [0:1];

    logic [IDX_W-1:0] row_count;
    logic [IDX_W-1:0] col_count;
    logic [IDX_W-1:0] out_count;

    logic signed [IQ_WIDTH-1:0] in_bank_i   [0:1][0:TOTAL-1];
    logic signed [IQ_WIDTH-1:0] in_bank_q   [0:1][0:TOTAL-1];
    logic signed [OUT_WIDTH-1:0] row_bank_i [0:1][0:TOTAL-1];
    logic signed [OUT_WIDTH-1:0] row_bank_q [0:1][0:TOTAL-1];
    logic signed [OUT_WIDTH-1:0] out_bank_i [0:1][0:TOTAL-1];
    logic signed [OUT_WIDTH-1:0] out_bank_q [0:1][0:TOTAL-1];

    // Twiddle LUTs (Q(TW_FRAC) fixed-point), indexed over one full turn.
    logic signed [TW_W-1:0] tw_cos [0:MAX_FFT-1];
    logic signed [TW_W-1:0] tw_sin [0:MAX_FFT-1];

    integer r;
    integer c;
    integer lin;
    integer ti;
    real ang;

    function automatic int int_sqrt_floor(input int v);
        int x;
        begin
            x = 0;
            while (((x + 1) * (x + 1)) <= v)
                x = x + 1;
            if (x == 0)
                int_sqrt_floor = 1;
            else
                int_sqrt_floor = x;
        end
    endfunction

    // Match Python vector generation (np.rint) with nearest-integer twiddle quantization.
    function automatic int quantize_twiddle(input real v);
        begin
            if (v >= 0.0)
                quantize_twiddle = $rtoi(v + 0.5);
            else
                quantize_twiddle = $rtoi(v - 0.5);
        end
    endfunction

    initial begin
        for (ti = 0; ti < MAX_FFT; ti = ti + 1) begin
            ang = (2.0 * PI_R * ti) / MAX_FFT;
            tw_cos[ti] = quantize_twiddle($cos(ang) * (1 << TW_FRAC));
            tw_sin[ti] = quantize_twiddle($sin(ang) * (1 << TW_FRAC));
        end
    end

    assign busy = (state != S_IDLE) || bank_full[0] || bank_full[1];
    assign out_valid = (state == S_STREAM);
    assign out_i = out_bank_i[proc_bank_sel][out_count];
    assign out_q = out_bank_q[proc_bank_sel][out_count];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            cap_bank_sel <= 1'b0;
            proc_bank_sel <= 1'b0;
            bank_full[0] <= 1'b0;
            bank_full[1] <= 1'b0;
            row_count <= '0;
            col_count <= '0;
            out_count <= '0;
            frame_start <= 1'b0;
            frame_done <= 1'b0;
        end else begin
            frame_start <= 1'b0;
            frame_done <= 1'b0;

            // Capture a completed grid frame into the active capture bank.
            // The grid_loader holds data stable after grid_valid until frame_start.
            if (grid_valid && !bank_full[cap_bank_sel]) begin
                for (r = 0; r < M; r = r + 1) begin
                    for (c = 0; c < N; c = c + 1) begin
                        lin = (r * N) + c;
                        in_bank_i[cap_bank_sel][lin] <= grid_i[r][c];
                        in_bank_q[cap_bank_sel][lin] <= grid_q[r][c];
                    end
                end
                bank_full[cap_bank_sel] <= 1'b1;
                cap_bank_sel <= ~cap_bank_sel;

                // Release grid_loader to start accepting next frame.
                frame_start <= 1'b1;
            end

            case (state)
                S_IDLE: begin
                    row_count <= '0;
                    col_count <= '0;
                    out_count <= '0;

                    if (bank_full[proc_bank_sel]) begin
                        state <= S_ROW_PASS;
                    end else if (bank_full[~proc_bank_sel]) begin
                        proc_bank_sel <= ~proc_bank_sel;
                        state <= S_ROW_PASS;
                    end
                end

                S_ROW_PASS: begin
                    // Generic row-wise IFFT using LUT twiddles:
                    // y[k] = (1/sqrt(N)) * sum_n x[n] * exp(+j*2*pi*k*n/N)
                    if ((N <= MAX_FFT) && ((MAX_FFT % N) == 0)) begin
                        int rr;
                        int kk;
                        int nn;
                        int idx;
                        int phase;
                        int signed wr;
                        int signed wi;
                        int signed xr;
                        int signed xi;
                        int signed pr;
                        int signed pi;
                        int signed acc_r;
                        int signed acc_i;
                        int sN;

                        rr = row_count / N;
                        kk = row_count % N;

                        acc_r = 0;
                        acc_i = 0;

                        for (nn = 0; nn < N; nn = nn + 1) begin
                            idx = rr*N + nn;
                            xr = in_bank_i[proc_bank_sel][idx];
                            xi = in_bank_q[proc_bank_sel][idx];

                            phase = ((kk * nn) * MAX_FFT) / N;
                            phase = phase % MAX_FFT;
                            wr = tw_cos[phase];
                            wi = tw_sin[phase]; // +j for IFFT

                            pr = (xr * wr - xi * wi) >>> TW_FRAC;
                            pi = (xr * wi + xi * wr) >>> TW_FRAC;

                            acc_r = acc_r + pr;
                            acc_i = acc_i + pi;
                        end

                        sN = int_sqrt_floor(N);
                        row_bank_i[proc_bank_sel][row_count] <= $signed(acc_r / sN);
                        row_bank_q[proc_bank_sel][row_count] <= $signed(acc_i / sN);
                    end else begin
                        // Unsupported length fallback.
                        row_bank_i[proc_bank_sel][row_count] <= $signed(in_bank_i[proc_bank_sel][row_count]);
                        row_bank_q[proc_bank_sel][row_count] <= $signed(in_bank_q[proc_bank_sel][row_count]);
                    end

                    if (row_count == TOTAL-1) begin
                        row_count <= '0;
                        state <= S_COL_PASS;
                    end else begin
                        row_count <= row_count + 1'b1;
                    end
                end

                S_COL_PASS: begin
                    // Generic column-wise FFT using LUT twiddles:
                    // y[r] = (1/sqrt(M)) * sum_n x[n] * exp(-j*2*pi*r*n/M)
                    if ((M <= MAX_FFT) && ((MAX_FFT % M) == 0)) begin
                        int rr;
                        int cc;
                        int nn;
                        int idx;
                        int phase;
                        int signed wr;
                        int signed wi;
                        int signed xr;
                        int signed xi;
                        int signed pr;
                        int signed pi;
                        int signed acc_r;
                        int signed acc_i;
                        int sM;

                        rr = col_count / N;
                        cc = col_count % N;

                        acc_r = 0;
                        acc_i = 0;

                        for (nn = 0; nn < M; nn = nn + 1) begin
                            idx = nn*N + cc;
                            xr = row_bank_i[proc_bank_sel][idx];
                            xi = row_bank_q[proc_bank_sel][idx];

                            phase = ((rr * nn) * MAX_FFT) / M;
                            phase = phase % MAX_FFT;
                            wr = tw_cos[phase];
                            // Sign-extend before negation to avoid TW_W overflow at -min value.
                            wi = -$signed({{(32-TW_W){tw_sin[phase][TW_W-1]}}, tw_sin[phase]}); // -j for FFT

                            pr = (xr * wr - xi * wi) >>> TW_FRAC;
                            pi = (xr * wi + xi * wr) >>> TW_FRAC;

                            acc_r = acc_r + pr;
                            acc_i = acc_i + pi;
                        end

                        sM = int_sqrt_floor(M);
                        out_bank_i[proc_bank_sel][col_count] <= $signed(acc_r / sM);
                        out_bank_q[proc_bank_sel][col_count] <= $signed(acc_i / sM);
                    end else begin
                        // Unsupported length fallback.
                        out_bank_i[proc_bank_sel][col_count] <= row_bank_i[proc_bank_sel][col_count];
                        out_bank_q[proc_bank_sel][col_count] <= row_bank_q[proc_bank_sel][col_count];
                    end

                    if (col_count == TOTAL-1) begin
                        col_count <= '0;
                        state <= S_STREAM;
                    end else begin
                        col_count <= col_count + 1'b1;
                    end
                end

                S_STREAM: begin
                    if (out_valid && out_ready) begin
                        if (out_count == TOTAL-1) begin
                            bank_full[proc_bank_sel] <= 1'b0;
                            out_count <= '0;
                            frame_done <= 1'b1;
                            state <= S_IDLE;
                        end else begin
                            out_count <= out_count + 1'b1;
                        end
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
