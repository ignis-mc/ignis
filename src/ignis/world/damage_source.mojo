"""Sources of damage and healing: the `DamageSource` and `HealingSource`
interfaces of Dragonfly `server/world/entity.go`.
"""


trait DamageSource(Copyable, Deinitable):
    """A source of damage to an entity (Go `world.DamageSource`)."""

    def reduced_by_armour(self) -> Bool:
        """Reports whether armour reduces the damage (Go
        `ReducedByArmour`)."""
        ...

    def reduced_by_resistance(self) -> Bool:
        """Reports whether the resistance effect reduces the damage (Go
        `ReducedByResistance`)."""
        ...

    def fire(self) -> Bool:
        """Reports whether the damage is fire related, so that fire
        resistance ignores it (Go `Fire`)."""
        ...

    def ignore_totem(self) -> Bool:
        """Reports whether a totem of undying is ignored if the damage is
        lethal (Go `IgnoreTotem`)."""
        ...


trait HealingSource(Copyable, Deinitable):
    """A source of healing for an entity (Go `world.HealingSource`, a marker
    interface)."""

    pass
