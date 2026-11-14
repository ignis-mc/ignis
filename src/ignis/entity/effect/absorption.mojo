"""`Absorption`, ported from Dragonfly
`server/entity/effect/absorption.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Absorption(Defaultable, ImplicitlyCopyable, LastingType):
    """Absorption is a lasting effect that increases the health of an entity
    over the maximum. Once this extra health is lost, it will not
    regenerate (Go `effect.Absorption`).

    TODO(world-runtime): `Start`, `End`, which need entities."""

    comptime ID: Int = 22
    """The effect ID (Go `effect.Register(22, Absorption)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0x25, 0x52, 0xA5, 0xFF)
