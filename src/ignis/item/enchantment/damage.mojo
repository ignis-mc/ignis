"""Damage reduction by protection enchantments, ported from Dragonfly
`server/item/enchantment/damage.go` (`ProtectionFactor`)."""

from ...world.damage_source import DamageSource
from ..stack import Enchantment
from . import (
    BLAST_PROTECTION_ID,
    FEATHER_FALLING_ID,
    FIRE_PROTECTION_ID,
    PROJECTILE_PROTECTION_ID,
    PROTECTION_ID,
    AffectedDamageSource,
)
from .blast_protection import BlastProtection
from .feather_falling import FeatherFalling
from .fire_protection import FireProtection
from .projectile_protection import ProjectileProtection
from .protection import Protection


def damage_modifier(id: Int) -> Optional[Float64]:
    """Returns the reduction per level of a `DamageModifier` enchantment (Go
    `Modifier`), or None for others."""
    if id == PROTECTION_ID:
        return Protection().modifier()
    if id == FIRE_PROTECTION_ID:
        return FireProtection().modifier()
    if id == FEATHER_FALLING_ID:
        return FeatherFalling().modifier()
    if id == BLAST_PROTECTION_ID:
        return BlastProtection().modifier()
    if id == PROJECTILE_PROTECTION_ID:
        return ProjectileProtection().modifier()
    return None


def protection_factor[
    S: AffectedDamageSource
](src: S, enchantments: List[Enchantment]) -> Float64:
    """Returns the share of damage the enchantments take away, at most 0.8
    (Go `ProtectionFactor`)."""
    var f = 0.0
    for e in enchantments:
        var id = Int(e.id)
        var m = damage_modifier(id)
        if not m:
            continue
        var reduced = False
        if id == PROTECTION_ID and src.reduced_by_resistance():
            # Protection applies to everything resistance reduces.
            reduced = True
        elif src.affected_by_enchantment(id):
            reduced = True
        if reduced:
            f += Float64(e.level) * m.value()
    return min(f, 0.8)
