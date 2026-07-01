from __future__ import annotations

import numpy as np


def heisenberg_ifft(x_tf: np.ndarray) -> np.ndarray:
	"""Apply the OTFS Heisenberg IFFT block.

	This mirrors the Tx notebook implementation:
	``np.fft.ifft(X_TF, axis=0) * np.sqrt(M)``

	Args:
		x_tf: Time-frequency grid with shape ``(M, N)``.

	Returns:
		Complex time-domain slots with shape ``(M, N)``.
	"""
	if x_tf.ndim != 2:
		raise ValueError("x_tf must be a 2D array with shape (M, N).")

	m = x_tf.shape[0]
	return np.fft.ifft(x_tf, axis=0) * np.sqrt(m)


def serialize_slots(time_domain_slots: np.ndarray) -> np.ndarray:
	"""Serialize 2D slots into a 1D transmit frame in column-major order."""
	if time_domain_slots.ndim != 2:
		raise ValueError("time_domain_slots must be a 2D array with shape (M, N).")

	return time_domain_slots.flatten(order="F")


def add_cyclic_prefix(time_domain_slots: np.ndarray, cp_len: int) -> np.ndarray:
	"""Insert a cyclic prefix per slot and concatenate into one frame.

	Args:
		time_domain_slots: Time-domain slots with shape ``(M, N)``.
		cp_len: Number of tail samples copied to the front of each slot.

	Returns:
		1D CP-extended transmit frame.
	"""
	if time_domain_slots.ndim != 2:
		raise ValueError("time_domain_slots must be a 2D array with shape (M, N).")
	if cp_len < 0:
		raise ValueError("cp_len must be non-negative.")
	if cp_len > time_domain_slots.shape[0]:
		raise ValueError("cp_len cannot exceed slot length M.")

	slots_with_cp = []
	for slot in time_domain_slots.T:
		cp = slot[-cp_len:] if cp_len else np.array([], dtype=slot.dtype)
		slots_with_cp.append(np.concatenate([cp, slot]))

	return np.concatenate(slots_with_cp)
