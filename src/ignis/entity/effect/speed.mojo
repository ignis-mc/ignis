"""`Speed`, ported from Dragonfly
`server/entity/effect/speed.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Speed(Defaultable, ImplicitlyCopyable, LastingType):
    """Speed is a lasting effect that increases the speed of an entity by 20%
    for each level that the effect has (Go `effect.Speed`).

    TODO(world-runtime): `Start`, `End`, which need entities."""

    comptime ID: Int = 1
    """The effect ID (Go `effect.Register(1, Speed)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0x33, 0xEB, 0xFF, 0xFF)
