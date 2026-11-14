"""`ConduitPower`, ported from Dragonfly
`server/entity/effect/conduit_power.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct ConduitPower(Defaultable, ImplicitlyCopyable, LastingType):
    """ConduitPower is a lasting effect that grants the affected entity the
    ability to breathe underwater and allows the entity to break faster
    when underwater or in the rain. (Similarly to haste.) (Go
    `effect.ConduitPower`)."""

    comptime ID: Int = 26
    """The effect ID (Go `effect.Register(26, ConduitPower)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0x1D, 0xC2, 0xD1, 0xFF)

    def multiplier(self, lvl: Int) -> Float64:
        """Returns the multiplier of the effect at a level (Go
        `Multiplier`)."""
        var v = 1 - Float64(lvl) * 0.1
        if v < 0:
            v = 0
        return v
