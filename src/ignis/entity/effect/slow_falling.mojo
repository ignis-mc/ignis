"""`SlowFalling`, ported from Dragonfly
`server/entity/effect/slow_falling.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct SlowFalling(Defaultable, ImplicitlyCopyable, LastingType):
    """SlowFalling is a lasting effect that causes the affected entity to fall
    very slowly (Go `effect.SlowFalling`)."""

    comptime ID: Int = 27
    """The effect ID (Go `effect.Register(27, SlowFalling)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`).

        Returns:
            RGBA(0xf3, 0xcf, 0xb9, 0xff).
        """
        return RGBA(0xF3, 0xCF, 0xB9, 0xFF)
