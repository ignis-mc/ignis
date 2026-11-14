"""`Darkness`, ported from Dragonfly
`server/entity/effect/darkness.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Darkness(Defaultable, ImplicitlyCopyable, LastingType):
    """Darkness is a lasting effect that causes the player's vision to dim
    occasionally (Go `effect.Darkness`)."""

    comptime ID: Int = 30
    """The effect ID (Go `effect.Register(30, Darkness)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`).

        Returns:
            RGBA(0x29, 0x27, 0x21, 0xff).
        """
        return RGBA(0x29, 0x27, 0x21, 0xFF)
