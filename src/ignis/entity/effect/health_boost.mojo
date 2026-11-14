"""`HealthBoost`, ported from Dragonfly
`server/entity/effect/health_boost.go`.
"""

from ...internal.color import RGBA
from . import LastingType


@fieldwise_init
struct HealthBoost(Defaultable, ImplicitlyCopyable, LastingType):
    """HealthBoost causes the affected entity to have its maximum health
    changed for a specific duration (Go `effect.HealthBoost`).

    TODO(world-runtime): `Start`, `End`, which need entities."""

    comptime ID: Int = 21
    """The effect ID (Go `effect.Register(21, HealthBoost)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0xF8, 0x7D, 0x23, 0xFF)
