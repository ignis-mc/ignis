"""`Haste`, ported from Dragonfly
`server/entity/effect/haste.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Haste(Defaultable, ImplicitlyCopyable, LastingType):
    """Haste is a lasting effect that increases the mining speed of a player by
    20% for each level of the effect (Go `effect.Haste`)."""

    comptime ID: Int = 3
    """The effect ID (Go `effect.Register(3, Haste)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0xD9, 0xC0, 0x43, 0xFF)

    def multiplier(self, lvl: Int) -> Float64:
        """Returns the multiplier of the effect at a level (Go
        `Multiplier`)."""
        var v = 1 - Float64(lvl) * 0.1
        if v < 0:
            v = 0
        return v
