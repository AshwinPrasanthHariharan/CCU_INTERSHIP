module ifft_pingpong #(
    parameter int M         = 4,
    parameter int N         = 4,
    parameter int IQ_WIDTH  = 3,
    parameter int OUT_WIDTH = IQ_WIDTH + 4
)(
    input  logic clk,
    input  logic rst_n,

    input  logic frame_valid,
    input  logic signed [OUT_WIDTH-1:0] frame_i [0:M-1][0:N-1],
    input  logic signed [OUT_WIDTH-1:0] frame_q [0:M-1][0:N-1],

    output logic signed [OUT_WIDTH-1:0] time_i [0:M-1][0:N-1],
    output logic signed [OUT_WIDTH-1:0] time_q [0:M-1][0:N-1],

    output logic busy,
    output logic frame_done
);

    localparam int MAX_FFT = 64;
    localparam int TW_W    = 12;
    localparam int TW_FRAC = TW_W - 2;
    localparam real PI_R   = 3.14159265358979323846;

    typedef enum logic [0:0] {
        S_IDLE,
        S_COMPUTE
    } state_t;

    state_t state;

    logic signed [TW_W-1:0] tw_cos [0:MAX_FFT-1];
    logic signed [TW_W-1:0] tw_sin [0:MAX_FFT-1];

    integer r;
    integer c;
    integer nn;
    integer idx;
    integer phase;
    integer sM;
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

    assign busy = (state != S_IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            frame_done <= 1'b0;
        end else begin
            frame_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (frame_valid) begin
                        sM = int_sqrt_floor(M);

                        for (r = 0; r < M; r = r + 1) begin
                            for (c = 0; c < N; c = c + 1) begin
                                int signed acc_r;
                                int signed acc_i;
                                int signed xr;
                                int signed xi;
                                int signed wr;
                                int signed wi;

                                acc_r = 0;
                                acc_i = 0;

                                for (nn = 0; nn < M; nn = nn + 1) begin
                                    idx = nn * N + c;
                                    xr = frame_i[nn][c];
                                    xi = frame_q[nn][c];

                                    phase = ((r * nn) * MAX_FFT) / M;
                                    phase = phase % MAX_FFT;
                                    wr = tw_cos[phase];
                                    wi = tw_sin[phase];

                                    acc_r = acc_r + ((xr * wr - xi * wi) >>> TW_FRAC);
                                    acc_i = acc_i + ((xr * wi + xi * wr) >>> TW_FRAC);
                                end

                                time_i[r][c] <= acc_r / sM;
                                time_q[r][c] <= acc_i / sM;
                            end
                        end

                        frame_done <= 1'b1;
                        state <= S_COMPUTE;
                    end
                end

                S_COMPUTE: begin
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule