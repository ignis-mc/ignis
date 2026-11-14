"""`InstantHealth`, `InstantHealingSource`, ported from Dragonfly
`server/entity/effect/instant_health.go`.
"""

from ...internal.color import RGBA
from ...world.damage_source import HealingSource
from . import EffectType


@fieldwise_init
struct InstantHealth(Defaultable, EffectType, ImplicitlyCopyable):
    """InstantHealth is an instant effect that causes the player that it is
    applied to immediately regain some health. The amount of health
    regained depends on the effect level and potency (Go
    `effect.InstantHealth`).

    TODO(world-runtime): `Apply`, which need entities."""

    comptime ID: Int = 6
    """The effect ID (Go `effect.Register(6, InstantHealth)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0xF8, 0x24, 0x23, 0xFF)


@fieldwise_init
struct InstantHealingSource(HealingSource, ImplicitlyCopyable):
    """The healing source of instant health effects (Go
    `effect.InstantHealingSource`)."""
