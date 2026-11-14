"""`FatalPoison`, ported from Dragonfly
`server/entity/effect/fatal_poison.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct FatalPoison(Defaultable, ImplicitlyCopyable, LastingType):
    """FatalPoison is a lasting effect that causes the affected entity to lose
    health gradually. fatalPoison, unlike poison, can kill the entity it
    is applied to (Go `effect.FatalPoison`).

    TODO(world-runtime): `Apply`, which need entities."""

    comptime ID: Int = 25
    """The effect ID (Go `effect.Register(25, FatalPoison)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`).

        Returns:
            RGBA(0x4e, 0x93, 0x31, 0xff).
        """
        return RGBA(0x4E, 0x93, 0x31, 0xFF)
