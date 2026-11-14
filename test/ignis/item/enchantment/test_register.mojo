"""Checks the enchantments against Dragonfly (`test/data/world/defs.txt`):
names, levels, costs, rarities, compatibility with each other and with a
set of items, and the per-type values."""

from ignis.item.enchantment import EnchantmentType
from ignis.item.enchantment.blast_protection import BlastProtection
from ignis.item.enchantment.efficiency import Efficiency
from ignis.item.enchantment.feather_falling import FeatherFalling
from ignis.item.enchantment.fire_aspect import FireAspect
from ignis.item.enchantment.fire_protection import FireProtection
from ignis.item.enchantment.flame import Flame
from ignis.item.enchantment.infinity import Infinity
from ignis.item.enchantment.knockback import Knockback
from ignis.item.enchantment.mending import Mending
from ignis.item.enchantment.multishot import Multishot
from ignis.item.enchantment.piercing import Piercing
from ignis.item.enchantment.power import Power
from ignis.item.enchantment.projectile_protection import ProjectileProtection
from ignis.item.enchantment.protection import Protection
from ignis.item.enchantment.punch import Punch
from ignis.item.enchantment.quick_charge import QuickCharge
from ignis.item.enchantment.register import VanillaEnchantments
from ignis.item.enchantment.respiration import Respiration
from ignis.item.enchantment.sharpness import Sharpness
from ignis.item.enchantment.soul_speed import SoulSpeed
from ignis.item.enchantment.swift_sneak import SwiftSneak
from ignis.item.enchantment.thorns import ThornsDamageSource
from ignis.item.enchantment.vanishing import CurseOfVanishing
from ignis.item.enchantment_rarity import EnchantmentRarity
from std.testing import TestSuite, assert_equal, assert_true
from support.go_values import b01, f64, read_lines


def _per_level(name: String, max_level: Int, values: List[String]) -> String:
    return name + "=" + String(";").join(values)


def _extras(id: Int) -> String:
    var out = List[String]()
    var levels = List[Int]()
    var ml = VanillaEnchantments.max_level(id).value()
    for l in range(1, ml + 2):
        levels.append(l)
    var vs = List[String]()
    if id == Sharpness.ID:
        for l in levels:
            vs.append(f64(Sharpness().addend(l)))
        out.append(_per_level("addend", ml, vs))
    elif id == Efficiency.ID:
        for l in levels:
            vs.append(f64(Efficiency().addend(l)))
        out.append(_per_level("addend", ml, vs))
    elif id == Knockback.ID:
        for l in levels:
            vs.append(f64(Knockback().force(l)))
        out.append(_per_level("force", ml, vs))
    elif id == Power.ID:
        for l in levels:
            vs.append(f64(Power().power_damage(l)))
        out.append(_per_level("power_damage", ml, vs))
    elif id == Respiration.ID:
        for l in levels:
            vs.append(f64(Respiration().chance(l)))
        out.append(_per_level("chance", ml, vs))
    elif id == FireAspect.ID:
        for l in levels:
            vs.append(String(FireAspect().duration(l)))
        out.append(_per_level("duration", ml, vs))
    elif id == QuickCharge.ID:
        for l in levels:
            vs.append(String(QuickCharge().charge_duration(l)))
        out.append(_per_level("charge_duration", ml, vs))
    elif id == Protection.ID:
        out.append("modifier=" + f64(Protection().modifier()))
    elif id == FireProtection.ID:
        out.append("modifier=" + f64(FireProtection().modifier()))
    elif id == FeatherFalling.ID:
        out.append("modifier=" + f64(FeatherFalling().modifier()))
    elif id == BlastProtection.ID:
        out.append("modifier=" + f64(BlastProtection().modifier()))
    elif id == ProjectileProtection.ID:
        out.append("modifier=" + f64(ProjectileProtection().modifier()))
    elif id == Flame.ID:
        out.append("burn_duration=" + String(Flame().burn_duration()))
    elif id == Punch.ID:
        out.append(
            "knockback_multiplier=" + f64(Punch().knockback_multiplier())
        )
    elif id == Infinity.ID:
        out.append("consumes_arrows=" + b01(Infinity().consumes_arrows()))
    elif id == Multishot.ID:
        out.append(
            "multiple_projectiles=" + b01(Multishot().multiple_projectiles())
        )
    elif id == Piercing.ID:
        out.append("pierces=" + b01(Piercing().pierces()))
    elif id == Mending.ID:
        out.append("treasure=" + b01(Mending().treasure()))
    elif id == SoulSpeed.ID:
        out.append("treasure=" + b01(SoulSpeed().treasure()))
    elif id == SwiftSneak.ID:
        out.append("treasure=" + b01(SwiftSneak().treasure()))
    elif id == CurseOfVanishing.ID:
        out.append("curse=" + b01(CurseOfVanishing().curse()))
        out.append("treasure=" + b01(CurseOfVanishing().treasure()))
    return String(" ").join(out)


def _line[
    T: EnchantmentType
](t: T, items: List[Tuple[UInt16, Optional[Int]]]) -> String:
    var r = t.rarity()
    var costs = List[String]()
    for l in range(1, t.max_level() + 2):
        var c = t.cost(l)
        costs.append(String(t"{c[0]}-{c[1]}"))
    var compat = List[String]()
    var all_ids = VanillaEnchantments.ids()
    sort(all_ids)
    for o in all_ids:
        if t.compatible_with_enchantment(o):
            compat.append(String(o))
    var its = List[String]()
    var f = t.compatible_items()
    for i in range(len(items)):
        if f.matches(items[i][0], items[i][1]):
            its.append(String(i))
    return String(
        t"{T.ID}\t{t.name()}\t{t.max_level()}\t{r.name()},{r.cost()},"
        t"{r.weight()}\t{String(',').join(costs)}\t"
        t"{String(',').join(compat)}\t{String(',').join(its)}\t{_extras(T.ID)}"
    )


def _got(id: Int, items: List[Tuple[UInt16, Optional[Int]]]) -> String:
    comptime for i in range(len(VanillaEnchantments.Ts)):
        comptime T = VanillaEnchantments.Ts[i]
        if id == T.ID:
            return _line(T(), items)
    return "unknown"


def test_enchantments_match_dragonfly() raises:
    var items = List[Tuple[UInt16, Optional[Int]]]()
    var ids = List[Int]()
    var lines = List[String]()
    for line in read_lines("test/data/world/defs.txt"):
        var p = line.split("\t")
        if p[0] == "ench_item":
            var tool = Int(p[4])
            var t = Optional[Int](None) if tool == -2 else Optional[Int](tool)
            items.append((UInt16(Int(p[3])), t))
        elif p[0] == "enchantment":
            ids.append(Int(p[1]))
            lines.append(String(p[1]) + "\t" + String("\t").join(p[3:]))
    assert_equal(len(ids), 27)
    assert_equal(len(VanillaEnchantments.ids()), 27)
    for i in range(len(ids)):
        assert_true(VanillaEnchantments.contains(ids[i]))
        assert_equal(_got(ids[i], items), lines[i])


def test_rarity_and_sources() raises:
    assert_equal(EnchantmentRarity.VERY_RARE.cost(), 8)
    assert_equal(EnchantmentRarity.UNCOMMON.weight(), 5)
    var s = ThornsDamageSource()
    assert_true(s.reduced_by_resistance() and not s.reduced_by_armour())
    assert_true(VanillaEnchantments.compatible(Protection.ID, 5))
    assert_true(
        not VanillaEnchantments.compatible(Protection.ID, BlastProtection.ID)
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
