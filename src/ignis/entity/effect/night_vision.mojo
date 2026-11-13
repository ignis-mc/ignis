"""`NightVision`, ported from Dragonfly
`server/entity/effect/night_vision.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct NightVision(Defaultable, ImplicitlyCopyable, LastingType):
    """NightVision is a lasting effect that causes the affected entity to see
    in dark places as though they were fully lit up (Go
    `effect.NightVision`)."""

    comptime ID: Int = 16
    """The effect ID (Go `effect.Register(16, NightVision)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`).

        Returns:
            RGBA(0xc2, 0xff, 0x66, 0xff).
        """
        return RGBA(0xC2, 0xFF, 0x66, 0xFF)
