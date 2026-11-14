"""`Strength`, ported from Dragonfly
`server/entity/effect/strength.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Strength(Defaultable, ImplicitlyCopyable, LastingType):
    """Strength is a lasting effect that increases the damage dealt with melee
    attacks when applied to an entity (Go `effect.Strength`)."""

    comptime ID: Int = 5
    """The effect ID (Go `effect.Register(5, Strength)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0xFF, 0xC7, 0x00, 0xFF)

    def multiplier(self, lvl: Int) -> Float64:
        """Returns the multiplier of the effect at a level (Go
        `Multiplier`)."""
        return 0.3 * Float64(lvl)
