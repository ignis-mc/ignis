"""`Levitation`, ported from Dragonfly
`server/entity/effect/levitation.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Levitation(Defaultable, ImplicitlyCopyable, LastingType):
    """Levitation is a lasting effect that causes the affected entity to slowly
    levitate upwards. It is roughly the opposite of the slowFalling
    effect (Go `effect.Levitation`)."""

    comptime ID: Int = 24
    """The effect ID (Go `effect.Register(24, Levitation)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`).

        Returns:
            RGBA(0xce, 0xff, 0xff, 0xff).
        """
        return RGBA(0xCE, 0xFF, 0xFF, 0xFF)
