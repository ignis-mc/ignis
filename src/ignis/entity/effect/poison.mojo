"""`Poison`, `PoisonDamageSource`, ported from Dragonfly
`server/entity/effect/poison.go`.
"""

from ...internal.color import RGBA
from ...world.damage_source import DamageSource
from . import LastingType


@fieldwise_init
struct Poison(Defaultable, ImplicitlyCopyable, LastingType):
    """Poison is a lasting effect that causes the affected entity to lose
    health gradually. poison cannot kill, unlike fatalPoison (Go
    `effect.Poison`).

    TODO(world-runtime): `Apply`, which need entities."""

    comptime ID: Int = 19
    """The effect ID (Go `effect.Register(19, Poison)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`)."""
        return RGBA(0x87, 0xA3, 0x63, 0xFF)


@fieldwise_init
struct PoisonDamageSource(DamageSource, ImplicitlyCopyable):
    """The damage source of poison and fatal poison (Go
    `effect.PoisonDamageSource`)."""

    var fatal: Bool
    """Whether the damage came from fatal poison and may kill the entity."""

    def __init__(out self):
        """Creates the source (Go `PoisonDamageSource{}`)."""
        self.fatal = False

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
