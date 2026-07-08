from .constallation import Constellation, QAM16
def modulate(bits: list[int], constellation: Constellation = QAM16) -> list[complex]:
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