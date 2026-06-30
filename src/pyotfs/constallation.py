from dataclasses import dataclass
from typing import Mapping, Tuple


@dataclass
class Constellation:
    name: str
    bits_per_symbol: int
    # Axis-level Gray mapping (2 bits -> amplitude level).
    lut: Mapping[Tuple[int, int], int]


QAM16 = Constellation(
    name="16-QAM",
    bits_per_symbol=4,
    lut={
        (0, 0): -3,
        (0, 1): -1,
        (1, 1): +1,
        (1, 0): +3,
    },
)
