"""`Weakness`, ported from Dragonfly
`server/entity/effect/weakness.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Weakness(Defaultable, ImplicitlyCopyable, LastingType):
    """Weakness is a lasting effect that reduces the damage dealt to other
    entities with melee attacks (Go `effect.Weakness`)."""

    comptime ID: Int = 18
    """The effect ID (Go `effect.Register(18, Weakness)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0x48, 0x4D, 0x48, 0xFF)

    def multiplier(self, lvl: Int) -> Float64:
        """Returns the multiplier of the effect at a level (Go
        `Multiplier`)."""
        var v = 0.2 * Float64(lvl)
        if v > 1:
            v = 1
        return v
