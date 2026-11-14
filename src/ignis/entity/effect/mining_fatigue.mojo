"""`MiningFatigue`, ported from Dragonfly
`server/entity/effect/mining_fatigue.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct MiningFatigue(Defaultable, ImplicitlyCopyable, LastingType):
    """MiningFatigue is a lasting effect that decreases the mining speed of a
    player by 10% for each level of the effect (Go
    `effect.MiningFatigue`)."""

    comptime ID: Int = 4
    """The effect ID (Go `effect.Register(4, MiningFatigue)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0x4A, 0x42, 0x17, 0xFF)

    def multiplier(self, lvl: Int) -> Float64:
        """Returns the multiplier of the effect at a level (Go
        `Multiplier`)."""
        return 3.0 ** Float64(lvl)
