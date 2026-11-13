"""`Invisibility`, ported from Dragonfly
`server/entity/effect/invisibility.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Invisibility(Defaultable, ImplicitlyCopyable, LastingType):
    """Invisibility is a lasting effect that causes the affected entity to turn
    invisible. While invisible, the entity's armour is still visible and
    effect particles will still be displayed (Go `effect.Invisibility`).

    TODO(world-runtime): `Start`, `End`, which need entities."""

    comptime ID: Int = 14
    """The effect ID (Go `effect.Register(14, Invisibility)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`).

        Returns:
            RGBA(0xf6, 0xf6, 0xf6, 0xff).
        """
        return RGBA(0xF6, 0xF6, 0xF6, 0xFF)
