module fft_pingpong #(
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

	logic signed [TW_W-1:0] tw_cos [0:MAX_FFT-1];
	logic signed [TW_W-1:0] tw_sin [0:MAX_FFT-1];

	logic pending;

	integer r;
	integer c;
	integer nn;
	integer phase;
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
		int base;
		real frac;
		begin
			base = $rtoi(v);
			frac = v - $itor(base);
			if (v >= 0.0) begin
				if (frac > 0.5)
					base = base + 1;
				else if ((frac == 0.5) && ((base & 1) != 0))
					base = base + 1;
			end else begin
				if (frac < -0.5)
					base = base - 1;
				else if ((frac == -0.5) && ((base & 1) != 0))
					base = base - 1;
			end
			quantize_twiddle = base;
		end
	endfunction

	function automatic int round_ties_to_even_div(input int signed value, input int divisor);
		int signed quotient;
		int signed remainder;
		int signed abs_remainder;
		int signed half;
		begin
			quotient = value / divisor;
			remainder = value % divisor;
			abs_remainder = (remainder < 0) ? -remainder : remainder;
			half = divisor / 2;
			if (abs_remainder > half) begin
				quotient = quotient + ((value >= 0) ? 1 : -1);
			end else if ((abs_remainder == half) && ((quotient & 1) != 0)) begin
				quotient = quotient + ((value >= 0) ? 1 : -1);
			end
			round_ties_to_even_div = quotient;
		end
	endfunction

	function automatic logic signed [OUT_WIDTH-1:0] clip_out(input int signed value);
		int signed max_val;
		int signed min_val;
		begin
			max_val = (1 << (OUT_WIDTH - 1)) - 1;
			min_val = -(1 << (OUT_WIDTH - 1));
			if (value > max_val)
				clip_out = $signed({1'b0, max_val[OUT_WIDTH-2:0]});
			else if (value < min_val)
				clip_out = $signed({1'b1, min_val[OUT_WIDTH-2:0]});
			else
				clip_out = $signed({value[OUT_WIDTH-1], value[OUT_WIDTH-2:0]});
		end
	endfunction

	initial begin
		for (ti = 0; ti < MAX_FFT; ti = ti + 1) begin
			ang = (2.0 * PI_R * $itor(ti)) / $itor(MAX_FFT);
			tw_cos[ti] = TW_W'($signed(quantize_twiddle($cos(ang) * (1.0 * (1 << TW_FRAC)))));
			tw_sin[ti] = TW_W'($signed(quantize_twiddle($sin(ang) * (1.0 * (1 << TW_FRAC)))));
		end
	end

	assign busy = pending;

	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			pending <= 1'b0;
			frame_done <= 1'b0;
			for (r = 0; r < M; r = r + 1) begin
				for (c = 0; c < N; c = c + 1) begin
					time_i[r][c] <= '0;
					time_q[r][c] <= '0;
				end
			end
		end else begin
			frame_done <= 1'b0;
			if (frame_valid) begin
				int sM;
				sM = int_sqrt_floor(M);
				for (r = 0; r < M; r = r + 1) begin
					for (c = 0; c < N; c = c + 1) begin
						logic signed [31:0] acc_r;
						logic signed [31:0] acc_i;
						logic signed [31:0] xr;
						logic signed [31:0] xi;
						logic signed [31:0] wr;
						logic signed [31:0] wi;

						acc_r = 0;
						acc_i = 0;

						for (nn = 0; nn < M; nn = nn + 1) begin
							xr = $signed({{(32-OUT_WIDTH){frame_i[nn][c][OUT_WIDTH-1]}}, frame_i[nn][c]});
							xi = $signed({{(32-OUT_WIDTH){frame_q[nn][c][OUT_WIDTH-1]}}, frame_q[nn][c]});
							phase = ((r * nn) * MAX_FFT) / M;
							phase = phase % MAX_FFT;
							wr = $signed({{(32-TW_W){tw_cos[phase][TW_W-1]}}, tw_cos[phase]});
							wi = -$signed({{(32-TW_W){tw_sin[phase][TW_W-1]}}, tw_sin[phase]});

							acc_r = acc_r + ((xr * wr - xi * wi) >>> TW_FRAC);
							acc_i = acc_i + ((xr * wi + xi * wr) >>> TW_FRAC);
						end

						time_i[r][c] <= clip_out(round_ties_to_even_div(acc_r, sM));
						time_q[r][c] <= clip_out(round_ties_to_even_div(acc_i, sM));
					end
				end

				pending <= 1'b1;
				frame_done <= 1'b1;
			end else begin
				pending <= 1'b0;
			end
		end
	end

endmodule
