from __future__ import annotations

import numpy as np


def quantize_complex_grid(x: np.ndarray, width: int) -> np.ndarray:
	"""Quantize a complex-valued array to signed fixed-point integers."""
	q_min = -(1 << (width - 1))
	q_max = (1 << (width - 1)) - 1
	q = np.empty(x.shape, dtype=np.complex128)
	q.real = np.clip(np.round(x.real), q_min, q_max)
	q.imag = np.clip(np.round(x.imag), q_min, q_max)
	return q


def heisenberg_ifft(x_tf: np.ndarray, quantize: bool = True, iq_width: int = 4) -> np.ndarray:
	"""Apply the OTFS Heisenberg IFFT block.

	This mirrors the Tx notebook implementation:
	``np.fft.ifft(X_TF, axis=0) * np.sqrt(M)``

	Args:
		x_tf: Time-frequency grid with shape ``(M, N)``.
		quantize: If True, round and wrap real/imag parts to signed integers.
		iq_width: Bit width used when ``quantize`` is enabled.

	Returns:
		Complex time-domain slots with shape ``(M, N)``.
	"""
	if x_tf.ndim != 2:
		raise ValueError("x_tf must be a 2D array with shape (M, N).")

	m = x_tf.shape[0]
	y = np.fft.ifft(x_tf, axis=0) * np.sqrt(m)
	if quantize:
		y = quantize_complex_grid(y, iq_width)
	return y


def serialize_slots(time_domain_slots: np.ndarray) -> np.ndarray:
	"""Serialize 2D slots into a 1D transmit frame in column-major order."""
	if time_domain_slots.ndim != 2:
		raise ValueError("time_domain_slots must be a 2D array with shape (M, N).")

	return time_domain_slots.flatten(order="F")


def add_cyclic_prefix(time_domain_slots: np.ndarray, cp_len: int) -> np.ndarray:
	"""Insert a cyclic prefix per slot and concatenate into one frame."""
	rows_with_cp = []
	for row in time_domain_slots:
		cp = row[-cp_len:] if cp_len else np.array([], dtype=row.dtype)
		rows_with_cp.append(np.concatenate([cp, row]))
	return np.concatenate(rows_with_cp)


def generate_isfft_vectors(
	symbol_grid: np.ndarray,
	iq_width: int = 3,
	out_width: int | None = None,
	max_fft: int = 64,
	tw_w: int = 12,
) -> dict[str, np.ndarray]:
	"""Generate RTL-aligned ISFFT reference vectors from a complex symbol grid."""
	out_width = out_width or iq_width + 4
	m, n = symbol_grid.shape
	tw_frac = tw_w - 2
	s_n = int(np.sqrt(n))
	s_m = int(np.sqrt(m))
	
	# Quantization ranges
	in_min, in_max = -(1 << (iq_width - 1)), (1 << (iq_width - 1)) - 1
	out_min, out_max = -(1 << (out_width - 1)), (1 << (out_width - 1)) - 1
	
	# Precompute twiddle factors
	angles = 2.0 * np.pi * np.arange(max_fft) / max_fft
	tw_cos = np.round(np.cos(angles) * (1 << tw_frac)).astype(int)
	tw_sin = np.round(np.sin(angles) * (1 << tw_frac)).astype(int)
	
	# Quantize input
	in_i = [int(np.clip(np.round(v.real), in_min, in_max)) for v in symbol_grid.reshape(-1, order="C")]
	in_q = [int(np.clip(np.round(v.imag), in_min, in_max)) for v in symbol_grid.reshape(-1, order="C")]
	
	# Row FFT (column-wise)
	row_i = [0] * (m * n)
	row_q = [0] * (m * n)
	for rr in range(m):
		for kk in range(n):
			acc_r = acc_i = 0
			for nn in range(n):
				xr, xi = in_i[rr * n + nn], in_q[rr * n + nn]
				phase = ((kk * nn) * max_fft) // n % max_fft
				wr, wi = int(tw_cos[phase]), int(tw_sin[phase])
				acc_r += (xr * wr - xi * wi) >> tw_frac
				acc_i += (xr * wi + xi * wr) >> tw_frac
			row_i[rr * n + kk] = int(np.clip(np.round(acc_r / s_n), out_min, out_max))
			row_q[rr * n + kk] = int(np.clip(np.round(acc_i / s_n), out_min, out_max))
	
	# Column FFT (row-wise, inverse)
	out_i = [0] * (m * n)
	out_q = [0] * (m * n)
	for rr in range(m):
		for cc in range(n):
			acc_r = acc_i = 0
			for nn in range(m):
				xr, xi = row_i[nn * n + cc], row_q[nn * n + cc]
				phase = ((rr * nn) * max_fft) // m % max_fft
				wr, wi = int(tw_cos[phase]), -int(tw_sin[phase])
				acc_r += (xr * wr - xi * wi) >> tw_frac
				acc_i += (xr * wi + xi * wr) >> tw_frac
			out_i[rr * n + cc] = int(np.clip(np.round(acc_r / s_m), out_min, out_max))
			out_q[rr * n + cc] = int(np.clip(np.round(acc_i / s_m), out_min, out_max))
	
	return {
		"in_i": np.asarray(in_i, dtype=int),
		"in_q": np.asarray(in_q, dtype=int),
		"row_i": np.asarray(row_i, dtype=int),
		"row_q": np.asarray(row_q, dtype=int),
		"out_i": np.asarray(out_i, dtype=int),
		"out_q": np.asarray(out_q, dtype=int),
	}
