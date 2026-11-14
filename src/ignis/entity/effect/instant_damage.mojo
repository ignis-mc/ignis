"""`InstantDamage`, `InstantDamageSource`, ported from Dragonfly
`server/entity/effect/instant_damage.go`.
"""

from ...internal.color import RGBA
from ...world.damage_source import DamageSource
from . import EffectType


@fieldwise_init
struct InstantDamage(Defaultable, EffectType, ImplicitlyCopyable):
    """InstantDamage is an instant effect that causes a living entity to
    immediately take some damage, depending on the level and the potency
    of the effect (Go `effect.InstantDamage`).

    TODO(world-runtime): `Apply`, which need entities."""

    comptime ID: Int = 7
    """The effect ID (Go `effect.Register(7, InstantDamage)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0xA9, 0x65, 0x6A, 0xFF)


@fieldwise_init
struct InstantDamageSource(DamageSource, ImplicitlyCopyable):
    """The damage source of instant damage effects (Go
    `effect.InstantDamageSource`)."""

    def reduced_by_resistance(self) -> Bool:
        """See `DamageSource` (Go `ReducedByResistance`)."""
        return True

    def reduced_by_armour(self) -> Bool:
        """See `DamageSource` (Go `ReducedByArmour`)."""
        return False

    def fire(self) -> Bool:
        """See `DamageSource` (Go `Fire`)."""
        return False

    def ignore_totem(self) -> Bool:
        """See `DamageSource` (Go `IgnoreTotem`)."""
        return False
