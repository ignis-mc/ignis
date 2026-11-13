"""`Blindness`, ported from Dragonfly
`server/entity/effect/blindness.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Blindness(Defaultable, ImplicitlyCopyable, LastingType):
    """Blindness is a lasting effect that greatly reduces the vision range of
    the entity affected (Go `effect.Blindness`)."""

    comptime ID: Int = 15
    """The effect ID (Go `effect.Register(15, Blindness)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`).

        Returns:
            RGBA(0x1f, 0x1f, 0x23, 0xff).
        """
        return RGBA(0x1F, 0x1F, 0x23, 0xFF)
