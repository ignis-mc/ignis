"""`Regeneration`, `RegenerationHealingSource`, ported from Dragonfly
`server/entity/effect/regeneration.go`.
"""

from ...internal.color import RGBA
from ...world.damage_source import HealingSource
from . import LastingType


@fieldwise_init
struct Regeneration(Defaultable, ImplicitlyCopyable, LastingType):
    """Regeneration is an effect that causes the entity that it is added to
    slowly regenerate health. The level of the effect influences the
    speed with which the entity regenerates (Go `effect.Regeneration`).

    TODO(world-runtime): `Apply`, which need entities."""

    comptime ID: Int = 10
    """The effect ID (Go `effect.Register(10, Regeneration)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0xCD, 0x5C, 0xAB, 0xFF)


@fieldwise_init
struct RegenerationHealingSource(HealingSource, ImplicitlyCopyable):
    """The healing source of the regeneration effect (Go
    `effect.RegenerationHealingSource`)."""
