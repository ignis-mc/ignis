"""Tests for `ignis.item.inventory.armour`: damage reduction by armour and
protection enchantments, and knock-back resistance, against Dragonfly
(`interop/health`)."""

from std.memory import bitcast
from std.testing import TestSuite, assert_equal

from ignis.entity.damage import (
    DAMAGE_ATTACK,
    DAMAGE_EXPLOSION,
    DAMAGE_FALL,
    DAMAGE_FIRE,
    DAMAGE_INSTANT,
    DAMAGE_LAVA,
    DAMAGE_LIGHTNING,
    DAMAGE_PROJECTILE,
    DAMAGE_STARVATION,
    DAMAGE_VOID,
    AnyDamageSource,
)
from ignis.item.armour import ArmourTier
from ignis.item.boots import Boots
from ignis.item.chestplate import Chestplate
from ignis.item.enchantment import (
    BLAST_PROTECTION_ID,
    FEATHER_FALLING_ID,
    FIRE_PROTECTION_ID,
    PROJECTILE_PROTECTION_ID,
    PROTECTION_ID,
)
from ignis.item.helmet import Helmet
from ignis.item.inventory.armour import Armour
from ignis.item.leggings import Leggings
from ignis.item.stack import Enchantment, Stack

from support.entity_vectors import bits


def _bits_value(h: String) raises -> Float64:
    var u = UInt64(0)
    for i in range(h.byte_length()):
        var c = Int(h.as_bytes()[i])
        var d = c - 48 if c <= 57 else c - 87
        u = (u << 4) | UInt64(d)
    return bitcast[DType.float64](u)


def _ench(id: Int, level: Int) -> List[Enchantment]:
    return [Enchantment(Int16(id), level)]


def _full(t: ArmourTier, e: List[Enchantment] = []) -> List[Stack]:
    return [
        Stack(Helmet(tier=t), 1).with_forced_enchantments(e),
        Stack(Chestplate(tier=t), 1).with_forced_enchantments(e),
        Stack(Leggings(tier=t), 1).with_forced_enchantments(e),
        Stack(Boots(tier=t), 1).with_forced_enchantments(e),
    ]


def _set(name: String) -> Armour:
    var s = List[Stack]()
    if name == "leather":
        s = _full(ArmourTier.LEATHER)
    elif name == "iron":
        s = _full(ArmourTier.IRON)
    elif name == "diamond":
        s = _full(ArmourTier.DIAMOND)
    elif name == "netherite":
        s = _full(ArmourTier.NETHERITE)
    elif name == "diamond_prot4":
        s = _full(ArmourTier.DIAMOND, _ench(PROTECTION_ID, 4))
    elif name == "iron_prot2":
        s = _full(ArmourTier.IRON, _ench(PROTECTION_ID, 2))
    elif name == "mixed":
        var boots = _ench(FEATHER_FALLING_ID, 4)
        boots.append(Enchantment(Int16(FIRE_PROTECTION_ID), 2))
        s = [
            Stack(Helmet(tier=ArmourTier.IRON), 1),
            Stack(
                Chestplate(tier=ArmourTier.DIAMOND), 1
            ).with_forced_enchantments(_ench(BLAST_PROTECTION_ID, 4)),
            Stack(Leggings(tier=ArmourTier.CHAIN), 1).with_forced_enchantments(
                _ench(PROJECTILE_PROTECTION_ID, 3)
            ),
            Stack(Boots(tier=ArmourTier.GOLD), 1).with_forced_enchantments(
                boots
            ),
        ]
    var a = Armour()
    if len(s) == 4:
        a.set(s[0], s[1], s[2], s[3])
    return a^


def _source(name: String) -> AnyDamageSource:
    if name == "attack":
        return AnyDamageSource(DAMAGE_ATTACK)
    if name == "fall":
        return AnyDamageSource(DAMAGE_FALL)
    if name == "projectile":
        return AnyDamageSource(DAMAGE_PROJECTILE)
    if name == "explosion":
        return AnyDamageSource(DAMAGE_EXPLOSION)
    if name == "fire":
        return AnyDamageSource(DAMAGE_FIRE)
    if name == "lava":
        return AnyDamageSource(DAMAGE_LAVA)
    if name == "void":
        return AnyDamageSource(DAMAGE_VOID)
    if name == "starvation":
        return AnyDamageSource(DAMAGE_STARVATION)
    if name == "instant":
        return AnyDamageSource(DAMAGE_INSTANT)
    return AnyDamageSource(DAMAGE_LIGHTNING)


def test_damage_reduction_matches_dragonfly() raises:
    var n = 0
    with open("test/data/health/damage.txt", "r") as f:
        for raw in f.read().split("\n"):
            var p = String(raw).split("\t")
            if len(p) == 0 or String(p[0]) == "xp" or len(p) < 3:
                continue
            var a = _set(String(p[1]))
            if String(p[0]) == "kb":
                assert_equal(
                    bits(a.knock_back_resistance()), String(p[2]), String(p[1])
                )
                continue
            var dmg = _bits_value(String(p[3]))
            var got = a.damage_reduction(dmg, _source(String(p[2])))
            assert_equal(bits(got), String(p[4]), String(raw))
            n += 1
    assert_equal(n, 480)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
