from __future__ import annotations

import numpy as np


def _wrap_signed(v: int, width: int) -> int:
	mask = (1 << width) - 1
	u = int(v) & mask
	if u >= (1 << (width - 1)):
		u -= (1 << width)
	return u


def _quantize_real(v: np.ndarray, width: int) -> np.ndarray:
	return np.vectorize(lambda x: _wrap_signed(int(np.rint(x)), width))(v)


def quantize_complex_grid(x: np.ndarray, width: int) -> np.ndarray:
	"""Quantize a complex-valued array to signed fixed-point integers."""
	if x.ndim != 2:
		raise ValueError("x must be a 2D array with shape (M, N).")
	if width < 2:
		raise ValueError("width must be at least 2.")

	q = np.empty(x.shape, dtype=np.complex128)
	q.real = _quantize_real(np.real(x), width)
	q.imag = _quantize_real(np.imag(x), width)
	return q


def heisenberg_ifft(x_tf: np.ndarray, quantize: bool = False, iq_width: int = 3) -> np.ndarray:
	"""Apply the OTFS Heisenberg IFFT block.

	This mirrors the Tx notebook implementation:
	``np.fft.ifft(X_TF, axis=0) * np.sqrt(M)``

	Args:
		x_tf: Time-frequency gritx_complex_samplesd with shape ``(M, N)``.
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
	"""Insert a cyclic prefix per slot and concatenate into one frame.

	Args:
		time_domain_slots: Time-domain slots with shape ``(M, N)``.
		cp_len: Number of tail samples copied to the front of each row.

	Returns:
		1D CP-extended transmit frame.
	"""
	if time_domain_slots.ndim != 2:
		raise ValueError("time_domain_slots must be a 2D array with shape (M, N).")
	if cp_len < 0:
		raise ValueError("cp_len must be non-negative.")
	if cp_len > time_domain_slots.shape[1]:
		raise ValueError("cp_len cannot exceed row length N.")

	rows_with_cp = []
	for row in time_domain_slots:
		cp = row[-cp_len:] if cp_len else np.array([], dtype=row.dtype)
		rows_with_cp.append(np.concatenate([cp, row]))

	return np.concatenate(rows_with_cp)


def _trunc_div_toward_zero(a: int, b: int) -> int:
	return int(a / b)


def _int_sqrt_floor(v: int) -> int:
	x = 0
	while (x + 1) * (x + 1) <= v:
		x += 1
	return max(x, 1)





def generate_isfft_vectors(
	symbol_grid: np.ndarray,
	iq_width: int = 3,
	out_width: int | None = None,
	max_fft: int = 64,
	tw_w: int = 12,
) -> dict[str, np.ndarray]:
	"""Generate RTL-aligned ISFFT reference vectors from a complex symbol grid.

	The helper keeps the exact fixed-point arithmetic used by the notebook, but
	centralizes the implementation inside ``pyotfs`` so the notebook stays thin.
	"""
	if symbol_grid.ndim != 2:
		raise ValueError("symbol_grid must be a 2D array with shape (M, N).")
	if iq_width < 2:
		raise ValueError("iq_width must be at least 2.")
	if out_width is None:
		out_width = iq_width + 4

	m, n = symbol_grid.shape
	tw_frac = tw_w - 2
	angles = 2.0 * np.pi * np.arange(max_fft) / max_fft
	tw_cos = np.rint(np.cos(angles) * (1 << tw_frac)).astype(int)
	tw_sin = np.rint(np.sin(angles) * (1 << tw_frac)).astype(int)

	in_i = [_wrap_signed(int(np.rint(value.real)), iq_width) for value in symbol_grid.reshape(-1, order="C")]
	in_q = [_wrap_signed(int(np.rint(value.imag)), iq_width) for value in symbol_grid.reshape(-1, order="C")]

	row_i = [0] * (m * n)
	row_q = [0] * (m * n)
	s_n = _int_sqrt_floor(n)
	for rr in range(m):
		for kk in range(n):
			acc_r = 0
			acc_i = 0
			for nn in range(n):
				idx = rr * n + nn
				xr = in_i[idx]
				xi = in_q[idx]
				phase = ((kk * nn) * max_fft) // n % max_fft
				wr = int(tw_cos[phase])
				wi = int(tw_sin[phase])
				acc_r += (xr * wr - xi * wi) >> tw_frac
				acc_i += (xr * wi + xi * wr) >> tw_frac
			out_idx = rr * n + kk
			row_i[out_idx] = _wrap_signed(_trunc_div_toward_zero(acc_r, s_n), out_width)
			row_q[out_idx] = _wrap_signed(_trunc_div_toward_zero(acc_i, s_n), out_width)

	out_i = [0] * (m * n)
	out_q = [0] * (m * n)
	s_m = _int_sqrt_floor(m)
	for rr in range(m):
		for cc in range(n):
			acc_r = 0
			acc_i = 0
			for nn in range(m):
				idx = nn * n + cc
				xr = row_i[idx]
				xi = row_q[idx]
				phase = ((rr * nn) * max_fft) // m % max_fft
				wr = int(tw_cos[phase])
				wi = -int(tw_sin[phase])
				acc_r += (xr * wr - xi * wi) >> tw_frac
				acc_i += (xr * wi + xi * wr) >> tw_frac
			out_idx = rr * n + cc
			out_i[out_idx] = _wrap_signed(_trunc_div_toward_zero(acc_r, s_m), out_width)
			out_q[out_idx] = _wrap_signed(_trunc_div_toward_zero(acc_i, s_m), out_width)

	return {
		"in_i": np.asarray(in_i, dtype=int),
		"in_q": np.asarray(in_q, dtype=int),
		"row_i": np.asarray(row_i, dtype=int),
		"row_q": np.asarray(row_q, dtype=int),
		"out_i": np.asarray(out_i, dtype=int),
		"out_q": np.asarray(out_q, dtype=int),
	}
