from dataclasses import dataclass, field
from .constallation import Constellation, QAM16
from .modulation import modulate


@dataclass
class System:
    M: int
    N: int
    delta_f: float
    cp_ln: int = 0
    constellation: Constellation = field(
        default_factory=lambda: Constellation(
            name=QAM16.name,
            bits_per_symbol=QAM16.bits_per_symbol,
            lut=dict(QAM16.lut),
        )
    )

    def modulate_bits(self, bits: list[int]) -> list[complex]:
        """
        Modulate a sequence of bits into complex symbols using the system's constellation.

        Args:
            bits (list[int]): A list of bits (0s and 1s) to be modulated.

        Returns:
            list[complex]: A list of complex symbols representing the modulated signal.
        """
        return modulate(bits, self.constellation)
