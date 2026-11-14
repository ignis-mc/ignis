"""`FireResistance`, ported from Dragonfly
`server/entity/effect/fire_resistance.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct FireResistance(Defaultable, ImplicitlyCopyable, LastingType):
    """FireResistance is a lasting effect that grants immunity to fire & lava
    damage (Go `effect.FireResistance`)."""

    comptime ID: Int = 12
    """The effect ID (Go `effect.Register(12, FireResistance)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0xFF, 0x99, 0x00, 0xFF)
