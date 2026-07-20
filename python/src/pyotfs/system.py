from dataclasses import dataclass, field
import numpy as np
from .constallation import Constellation, QAM16
from .ifft import add_cyclic_prefix, heisenberg_ifft, serialize_slots
from .modulation import modulate,constilate


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

    def constilate(self, bits: list[int]) -> list[complex]:
        """
        Modulate a sequence of bits into complex symbols using the system's constellation.

        Args:
            bits (list[int]): A list of bits (0s and 1s) to be modulated.

        Returns:
            list[complex]: A list of complex symbols representing the modulated signal.
        """
        return constilate(bits, self.constellation)
    def modulate(self, D: np.ndarray) -> np.ndarray:
        """Run the OTFS modulation stage on a 2D symbol grid."""
        if D.ndim != 2:
            raise ValueError("D must be a 2D array with shape (M, N).")
        if D.shape != (self.M, self.N):
            raise ValueError(f"D shape must be ({self.M}, {self.N}).")
        return modulate(D, self.M, self.N)

    def ifft_block(self, x_tf: np.ndarray) -> np.ndarray:
        """Run the Heisenberg IFFT stage on a time-frequency grid."""
        if x_tf.ndim != 2:
            raise ValueError("x_tf must be a 2D array with shape (M, N).")
        if x_tf.shape != (self.M, self.N):
            raise ValueError(f"x_tf shape must be ({self.M}, {self.N}).")
        return heisenberg_ifft(x_tf)

    def serialize_ifft_output(self, time_domain_slots: np.ndarray) -> np.ndarray:
        """Serialize IFFT slots into one transmit frame (column-major)."""
        if time_domain_slots.ndim != 2:
            raise ValueError("time_domain_slots must be a 2D array with shape (M, N).")
        if time_domain_slots.shape != (self.M, self.N):
            raise ValueError(f"time_domain_slots shape must be ({self.M}, {self.N}).")
        return serialize_slots(time_domain_slots)

    def add_cp(self, time_domain_slots: np.ndarray, cp_len: int | None = None) -> np.ndarray:
        """Add cyclic prefix to each slot and concatenate into one frame."""
        if cp_len is None:
            cp_len = self.cp_ln
        if time_domain_slots.ndim != 2:
            raise ValueError("time_domain_slots must be a 2D array with shape (M, N).")
        if time_domain_slots.shape != (self.M, self.N):
            raise ValueError(f"time_domain_slots shape must be ({self.M}, {self.N}).")
        return add_cyclic_prefix(time_domain_slots, cp_len)
