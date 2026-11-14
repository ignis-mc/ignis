"""`Resistance`, ported from Dragonfly
`server/entity/effect/resistance.go`.
"""

from ...internal.color import RGBA
from ...world.damage_source import DamageSource
from . import LastingType


@fieldwise_init
struct Resistance(Defaultable, ImplicitlyCopyable, LastingType):
    """Resistance is a lasting effect that reduces the damage taken from any
    sources except for void damage or custom damage (Go
    `effect.Resistance`)."""

    comptime ID: Int = 11
    """The effect ID (Go `effect.Register(11, Resistance)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0x91, 0x46, 0xF0, 0xFF)

    def multiplier[S: DamageSource](self, e: S, lvl: Int) -> Float64:
        """Returns the damage multiplier of the effect at a level (Go
        `Multiplier`)."""
        if not e.reduced_by_resistance():
            return 1
        var v = 1 - 0.2 * Float64(lvl)
        if v >= 0:
            return v
        return 0
