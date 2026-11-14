"""Tests for `ignis.player.living`."""

from std.testing import TestSuite, assert_equal, assert_true

from ignis.entity.damage import (
    DAMAGE_ATTACK,
    DAMAGE_FALL,
    DAMAGE_LAVA,
    AnyDamageSource,
)
from ignis.entity.effect import SECOND, new, new_instant
from ignis.entity.effect.absorption import Absorption
from ignis.entity.effect.health_boost import HealthBoost
from ignis.entity.effect.hunger import Hunger
from ignis.entity.effect.instant_damage import InstantDamage
from ignis.entity.effect.poison import Poison
from ignis.entity.effect.regeneration import Regeneration
from ignis.entity.effect.wither import Wither
from ignis.item.armour import ArmourTier
from ignis.item.boots import Boots
from ignis.item.chestplate import Chestplate
from ignis.item.helmet import Helmet
from ignis.item.leggings import Leggings
from ignis.item.stack import Stack

from support.entity_vectors import bits
from ignis.item.inventory.armour import Armour
from ignis.player.living import EVENT_DEATH, Living, SurvivalContext


def test_hurt_and_immunity() raises:
    var l = Living()
    var a = Armour()
    var ctx = SurvivalContext()
    var r = l.hurt(5, AnyDamageSource(DAMAGE_ATTACK), a, ctx)
    assert_equal(r[0], 5.0)
    assert_equal(l.health.health, 15.0)
    # Within half a second only damage above the last counts.
    ctx.now_ms = 200
    r = l.hurt(3, AnyDamageSource(DAMAGE_ATTACK), a, ctx)
    assert_true(not r[1])
    r = l.hurt(7, AnyDamageSource(DAMAGE_ATTACK), a, ctx)
    assert_equal(l.health.health, 13.0)
    ctx.now_ms = 1000
    _ = l.hurt(20, AnyDamageSource(DAMAGE_FALL), a, ctx)
    assert_true(l.dead())
    var deaths = 0
    for e in l.take_events():
        if e.kind == EVENT_DEATH:
            deaths += 1
    assert_equal(deaths, 1)


def test_regeneration_effect() raises:
    var l = Living()
    var a = Armour()
    var ctx = SurvivalContext()
    l.health.health = 10
    l.add_effect(new(Regeneration(), 2, 5 * SECOND), ctx)
    for _ in range(100):
        l.tick_effects(a, ctx)
    # Regeneration II heals every 25 ticks.
    assert_equal(l.health.health, 14.0)


def _line(name: String, tick: Int, l: Living) -> String:
    var h = l.hunger.copy()
    return String(
        t"living\t{name}\t{tick}\t{bits(l.health.health)}\t{bits(l.health.max)}\t{bits(l.absorption)}\t{h.food_level}\t{bits(h.saturation_level)}\t{bits(h.exhaustion_level)}\t{h.food_tick}"
    )


def _diamond() -> Armour:
    var a = Armour()
    a.set(
        Stack(Helmet(tier=ArmourTier.DIAMOND), 1),
        Stack(Chestplate(tier=ArmourTier.DIAMOND), 1),
        Stack(Leggings(tier=ArmourTier.DIAMOND), 1),
        Stack(Boots(tier=ArmourTier.DIAMOND), 1),
    )
    return a^


def _scenario(name: String, ticks: Int) raises:
    var want = List[String]()
    with open("test/data/health/living.txt", "r") as f:
        for raw in f.read().split("\n"):
            var line = String(raw)
            if line.startswith(String(t"living\t{name}\t")):
                want.append(line)
    var l = Living()
    var a = Armour()
    var ctx = SurvivalContext()
    # Dragonfly's default difficulty is normal.
    ctx.starvation_health_limit = 1
    if name == "starve":
        l.hunger.food_level = 0
        l.hunger.saturation_level = 0
        l.hunger.food_tick = 1
    elif name == "regen_saturated":
        l.health.health = 10
    elif name == "regen_slow":
        l.health.health = 10
        l.hunger.food_level = 18
        l.hunger.saturation_level = 0
        l.hunger.food_tick = 1
    elif name == "regen_effect":
        l.health.health = 8
        l.add_effect(new(Regeneration(), 2, 4 * SECOND), ctx)
    elif name == "effects":
        l.add_effect(new(Poison(), 2, 3 * SECOND), ctx)
        l.add_effect(new(Hunger(), 3, 5 * SECOND), ctx)
        l.add_effect(new(Wither(), 1, 6 * SECOND), ctx)
    elif name == "absorption":
        l.add_effect(new(Absorption(), 2, 2 * SECOND), ctx)
        l.add_effect(new(HealthBoost(), 1, 3 * SECOND), ctx)
        _ = l.hurt(6, AnyDamageSource(DAMAGE_ATTACK), a, ctx)
    elif name == "fire":
        l.set_on_fire(3000)
    elif name == "armour_hurt":
        a = _diamond()
        _ = l.hurt(10, AnyDamageSource(DAMAGE_ATTACK), a, ctx)
        _ = l.hurt(4, AnyDamageSource(DAMAGE_LAVA), a, ctx)
        l.add_effect(new_instant(InstantDamage(), 1), ctx)
    var got = List[String]()
    got.append(_line(name, 0, l))
    for tick in range(1, ticks + 1):
        ctx.now_ms = tick * 50
        l.tick(a, ctx)
        got.append(_line(name, tick, l))
    for i in range(min(len(got), len(want))):
        assert_equal(got[i], want[i], String(t"{name} tick {i}"))
    assert_equal(len(got), len(want), name)


def test_starve() raises:
    _scenario("starve", 260)


def test_regen_saturated() raises:
    _scenario("regen_saturated", 120)


def test_regen_slow() raises:
    _scenario("regen_slow", 260)


def test_regen_effect() raises:
    _scenario("regen_effect", 120)


def test_effects() raises:
    _scenario("effects", 140)


def test_absorption() raises:
    _scenario("absorption", 20)


def test_fire() raises:
    _scenario("fire", 90)


def test_armour_hurt() raises:
    _scenario("armour_hurt", 30)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
