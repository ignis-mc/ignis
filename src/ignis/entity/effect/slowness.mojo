"""`Slowness`, ported from Dragonfly
`server/entity/effect/slowness.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct Slowness(Defaultable, ImplicitlyCopyable, LastingType):
    """Slowness is a lasting effect that decreases the movement speed of a
    living entity by 15% for each level that the effect has (Go
    `effect.Slowness`).

    TODO(world-runtime): `Start`, `End`, which need entities."""

    comptime ID: Int = 2
    """The effect ID (Go `effect.Register(2, Slowness)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`).

        Returns:
            RGBA(0x8b, 0xaf, 0xe0, 0xff).
        """
        return RGBA(0x8B, 0xAF, 0xE0, 0xFF)
