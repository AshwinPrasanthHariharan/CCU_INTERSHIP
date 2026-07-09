from .constallation import Constellation, QAM16
import numpy as np
def constilate(bits: list[int], constellation: Constellation = QAM16) -> list[complex]:
    """
    Modulate a sequence of bits into complex symbols using the specified constellation.

    Args:
        bits (list[int]): A list of bits (0s and 1s) to be modulated.
        constellation (Constellation): The constellation to use for modulation.

    Returns:
        list[complex]: A list of complex symbols representing the modulated signal.
    """
    if len(bits) % constellation.bits_per_symbol != 0:
        raise ValueError("Number of bits must be a multiple of bits_per_symbol.")

    symbols = []
    # Explicit fixed-point quantization for RTL-aligned processing
    Q_BITS = 3
    Q_MIN = -(1 << (Q_BITS - 1))
    Q_MAX = (1 << (Q_BITS - 1)) - 1

    for i in range(0, len(bits), constellation.bits_per_symbol):
        bit_tuple = tuple(bits[i:i + constellation.bits_per_symbol])
        amplitude = (
        constellation.lut.get(bit_tuple[0:constellation.bits_per_symbol // 2]) +
        1j*constellation.lut.get(bit_tuple[constellation.bits_per_symbol // 2:])
        )
        if amplitude is None:
            raise ValueError(f"Bit tuple {bit_tuple} not found in LUT.")
        i_q = max(Q_MIN, min(Q_MAX, round(amplitude.real)))
        q_q = max(Q_MIN, min(Q_MAX, round(amplitude.imag)))
        symbols.append(complex(i_q, q_q))

    return symbols
def modulate(D: np.ndarray, M: int, N: int) -> np.ndarray:
    W_M = (1.0 / np.sqrt(M)) * np.fft.fft(np.eye(M))
    W_N_inv = (1.0 / np.sqrt(N)) * np.fft.ifft(np.eye(N)) * N  # Normalized scaling factor
    # Execute 2D matrix transformation to yield Time-Frequency Grid X_TF
    X_TF = np.dot(np.dot(W_M, D), W_N_inv)
    flat=X_TF.flatten(order="F")  # Column-major flattening for RTL alignment
    # Explicit fixed-point quantization for RTL-aligned processing
    Q_BITS = max(M,N)
    Q_MIN = -(1 << (Q_BITS - 1))
    Q_MAX = (1 << (Q_BITS - 1)) - 1
    for i in range(len(flat)):
        i_q = np.clip(np.trunc(flat[i].real), Q_MIN, Q_MAX)
        q_q = np.clip(np.trunc(flat[i].imag), Q_MIN, Q_MAX)
        flat[i] = complex(i_q, q_q)
    X_TF = flat.reshape((M, N), order="F")  # Reshape back to 2D grid in column-major order
    return X_TF