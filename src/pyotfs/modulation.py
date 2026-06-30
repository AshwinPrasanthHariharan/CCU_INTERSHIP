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
    for i in range(0, len(bits), constellation.bits_per_symbol):
        bit_tuple = tuple(bits[i:i + constellation.bits_per_symbol])
        amplitude = (
        constellation.lut.get(bit_tuple[0:constellation.bits_per_symbol // 2]) +
        1j*constellation.lut.get(bit_tuple[constellation.bits_per_symbol // 2:])
        )
        if amplitude is None:
            raise ValueError(f"Bit tuple {bit_tuple} not found in LUT.")
        symbols.append(complex(amplitude, 0))  # Assuming real axis modulation

    return symbols