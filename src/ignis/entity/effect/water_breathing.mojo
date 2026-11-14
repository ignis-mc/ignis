"""`WaterBreathing`, ported from Dragonfly
`server/entity/effect/water_breathing.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct WaterBreathing(Defaultable, ImplicitlyCopyable, LastingType):
    """WaterBreathing is a lasting effect that allows the affected entity to
    breath underwater until the effect expires (Go
    `effect.WaterBreathing`)."""

    comptime ID: Int = 13
    """The effect ID (Go `effect.Register(13, WaterBreathing)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0x98, 0xDA, 0xC0, 0xFF)
