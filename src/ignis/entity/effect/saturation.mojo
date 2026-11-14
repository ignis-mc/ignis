"""`Saturation`, ported from Dragonfly
`server/entity/effect/saturation.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Saturation(Defaultable, ImplicitlyCopyable, LastingType):
    """Saturation is a lasting effect that causes the affected player to regain
    food and saturation (Go `effect.Saturation`).

    TODO(world-runtime): `Apply`, which need entities."""

    comptime ID: Int = 23
    """The effect ID (Go `effect.Register(23, Saturation)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0xF8, 0x24, 0x23, 0xFF)
