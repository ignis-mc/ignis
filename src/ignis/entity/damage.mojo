"""Damage sources, ported from Dragonfly `server/entity/damage.go`, with the
sources of `player/hunger.go` (starvation), `block` (fire, lava, magma,
cactus) and `entity/effect` (instant damage, poison, wither) and
`enchantment.ThornsDamageSource`.

Go has one type per source; here `AnyDamageSource` holds a `kind` and the
data some kinds carry, so that damage can be queued and passed between the
world and the server. It conforms to `world.DamageSource`.
"""

from minecraft.protocol.uuid import UUID

from ..block.hash import AnyBlock
from ..item.enchantment import (
    BLAST_PROTECTION_ID,
    FEATHER_FALLING_ID,
    FIRE_PROTECTION_ID,
    PROJECTILE_PROTECTION_ID,
    AffectedDamageSource,
)
from ..mgl64 import Vec3
from ..world.damage_source import DamageSource

comptime DAMAGE_ATTACK = 0
"""Go `AttackDamageSource`."""
comptime DAMAGE_VOID = 1
"""Go `VoidDamageSource`."""
comptime DAMAGE_SUFFOCATION = 2
"""Go `SuffocationDamageSource`."""
comptime DAMAGE_DROWNING = 3
"""Go `DrowningDamageSource`."""
comptime DAMAGE_FALL = 4
"""Go `FallDamageSource`."""
comptime DAMAGE_GLIDE = 5
"""Go `GlideDamageSource`."""
comptime DAMAGE_LIGHTNING = 6
"""Go `LightningDamageSource`."""
comptime DAMAGE_PROJECTILE = 7
"""Go `ProjectileDamageSource`."""
comptime DAMAGE_EXPLOSION = 8
"""Go `ExplosionDamageSource`."""
comptime DAMAGE_STARVATION = 9
"""Go `player.StarvationDamageSource`."""
comptime DAMAGE_FIRE = 10
"""Go `block.FireDamageSource`."""
comptime DAMAGE_LAVA = 11
"""Go `block.LavaDamageSource`."""
comptime DAMAGE_MAGMA = 12
"""Go `block.MagmaDamageSource`."""
comptime DAMAGE_BLOCK = 13
"""Go `block.DamageSource` (cacti)."""
comptime DAMAGE_INSTANT = 14
"""Go `effect.InstantDamageSource`."""
comptime DAMAGE_POISON = 15
"""Go `effect.PoisonDamageSource`."""
comptime DAMAGE_WITHER = 16
"""Go `effect.WitherDamageSource`."""
comptime DAMAGE_THORNS = 17
"""Go `enchantment.ThornsDamageSource`."""


struct AnyDamageSource(AffectedDamageSource, ImplicitlyCopyable):
    """A source of damage of any kind (Go's `world.DamageSource` values)."""

    var kind: Int
    """One of the `DAMAGE_*` kinds."""
    var attacker: UUID
    """The attacker, projectile owner or thorns owner, if any."""
    var projectile: UUID
    """The projectile of projectile damage."""
    var explosion_pos: Vec3
    """Where an explosion happened."""
    var explosion_size: Float64
    """How big the explosion was."""
    var block: AnyBlock
    """The block of block damage."""
    var fatal: Bool
    """Whether poison damage may kill (Go `PoisonDamageSource.Fatal`)."""

    def __init__(out self, kind: Int, attacker: UUID = UUID()):
        """Creates a source of a kind."""
        self.kind = kind
        self.attacker = attacker
        self.projectile = UUID()
        self.explosion_pos = Vec3()
        self.explosion_size = 0
        self.block = AnyBlock(kind=0, state=0)
        self.fatal = False

    @staticmethod
    def projectile_source(projectile: UUID, owner: UUID) -> Self:
        """Returns Go's `ProjectileDamageSource{Projectile, Owner}`."""
        var s = Self(DAMAGE_PROJECTILE, owner)
        s.projectile = projectile
        return s

    @staticmethod
    def explosion(pos: Vec3, size: Float64) -> Self:
        """Returns Go's `ExplosionDamageSource{Source}`."""
        var s = Self(DAMAGE_EXPLOSION)
        s.explosion_pos = pos
        s.explosion_size = size
        return s

    def reduced_by_armour(self) -> Bool:
        """Reports whether armour reduces the damage (Go `ReducedByArmour`)."""
        var k = self.kind
        return (
            k == DAMAGE_ATTACK
            or k == DAMAGE_LIGHTNING
            or k == DAMAGE_PROJECTILE
            or k == DAMAGE_EXPLOSION
            or k == DAMAGE_FIRE
            or k == DAMAGE_LAVA
            or k == DAMAGE_MAGMA
            or k == DAMAGE_BLOCK
        )

    def reduced_by_resistance(self) -> Bool:
        """Reports whether resistance reduces the damage (Go
        `ReducedByResistance`)."""
        var k = self.kind
        return not (
            k == DAMAGE_VOID
            or k == DAMAGE_SUFFOCATION
            or k == DAMAGE_DROWNING
            or k == DAMAGE_STARVATION
        )

    def fire(self) -> Bool:
        """Reports whether the damage is fire (Go `Fire`)."""
        var k = self.kind
        return k == DAMAGE_FIRE or k == DAMAGE_LAVA or k == DAMAGE_MAGMA

    def ignore_totem(self) -> Bool:
        """Reports whether a totem does not save from it (Go
        `IgnoreTotem`)."""
        return self.kind == DAMAGE_VOID

    def affected_by_enchantment(self, id: Int) -> Bool:
        """Reports whether a protection enchantment reduces it (Go
        `AffectedByEnchantment`)."""
        var k = self.kind
        if k == DAMAGE_FALL:
            return id == FEATHER_FALLING_ID
        if k == DAMAGE_PROJECTILE:
            return id == PROJECTILE_PROTECTION_ID
        if k == DAMAGE_EXPLOSION:
            return id == BLAST_PROTECTION_ID
        if k == DAMAGE_FIRE or k == DAMAGE_MAGMA:
            return id == FIRE_PROTECTION_ID
        return False
