"""`Wither`, `WitherDamageSource`, ported from Dragonfly
`server/entity/effect/wither.go`.
"""

from ...internal.color import RGBA
from ...world.damage_source import DamageSource
from . import LastingType


@fieldwise_init
struct Wither(Defaultable, ImplicitlyCopyable, LastingType):
    """Wither is a lasting effect that causes an entity to take continuous
    damage that is capable of killing an entity (Go `effect.Wither`).

    TODO(world-runtime): `Apply`, which need entities."""

    comptime ID: Int = 20
    """The effect ID (Go `effect.Register(20, Wither)`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`).

        Returns:
            RGBA(0x73, 0x61, 0x56, 0xff).
        """
        return RGBA(0x73, 0x61, 0x56, 0xFF)


@fieldwise_init
struct WitherDamageSource(DamageSource, ImplicitlyCopyable):
    """The damage source of the wither effect (Go `effect.WitherDamageSource`).
    """

    def reduced_by_resistance(self) -> Bool:
        """See `DamageSource` (Go `ReducedByResistance`).

        Returns:
            True.
        """
        return True

    def reduced_by_armour(self) -> Bool:
        """See `DamageSource` (Go `ReducedByArmour`).

        Returns:
            False.
        """
        return False

    def fire(self) -> Bool:
        """See `DamageSource` (Go `Fire`).

        Returns:
            False.
        """
        return False

    def ignore_totem(self) -> Bool:
        """See `DamageSource` (Go `IgnoreTotem`).

        Returns:
            False.
        """
        return False
