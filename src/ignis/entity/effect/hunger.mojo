"""`Hunger`, ported from Dragonfly
`server/entity/effect/hunger.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Hunger(Defaultable, ImplicitlyCopyable, LastingType):
    """Hunger is a lasting effect that causes an affected player to gradually
    lose saturation and food (Go `effect.Hunger`).

    TODO(world-runtime): `Apply`, which need entities."""

    comptime ID: Int = 17
    """The effect ID (Go `effect.Register(17, Hunger)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0x58, 0x76, 0x53, 0xFF)
