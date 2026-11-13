"""Checks the effects against Dragonfly (`test/data/world/defs.txt`)."""

from ignis.entity.effect import (
    EffectType,
    LastingType,
    SECOND,
    Effect,
    new,
    new_ambient,
    new_infinite,
    new_instant,
    resulting_colour,
)
from ignis.entity.effect.conduit_power import ConduitPower
from ignis.entity.effect.haste import Haste
from ignis.entity.effect.instant_damage import InstantDamageSource
from ignis.entity.effect.instant_health import InstantHealth
from ignis.entity.effect.mining_fatigue import MiningFatigue
from ignis.entity.effect.poison import PoisonDamageSource
from ignis.entity.effect.register import VanillaEffects
from ignis.entity.effect.resistance import Resistance
from ignis.entity.effect.speed import Speed
from ignis.entity.effect.strength import Strength
from ignis.entity.effect.weakness import Weakness
from ignis.entity.effect.wither import WitherDamageSource
from ignis.world.damage_source import DamageSource
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.go_values import b01, f64, read_lines


@fieldwise_init
struct _NotResisted(DamageSource, ImplicitlyCopyable):
    def reduced_by_armour(self) -> Bool:
        return False

    def reduced_by_resistance(self) -> Bool:
        return False

    def fire(self) -> Bool:
        return False

    def ignore_totem(self) -> Bool:
        return False


def _effect[T: EffectType](t: T, flag: String) -> Effect:
    comptime if conforms_to(T, LastingType):
        if flag == "a":
            return _ambient[T](t)
        var e = _lasting[T](t)
        return e.without_particles() if flag == "h" else e
    var e = new_instant(t, 1)
    return e.without_particles() if flag == "h" else e


def _lasting[T: LastingType](t: T) -> Effect:
    return new(t, 1, SECOND)


def _ambient[T: LastingType](t: T) -> Effect:
    return new_ambient(t, 1, SECOND)


def _by_id(id: Int, flag: String) -> Effect:
    comptime for i in range(len(VanillaEffects.Ts)):
        comptime T = VanillaEffects.Ts[i]
        if id == T.ID:
            return _effect(T(), flag)
    return new_instant(InstantHealth(), 0)


def _mult(id: Int) -> String:
    var vs = List[String]()
    for lvl in range(7):
        if id == Haste.ID:
            vs.append(f64(Haste().multiplier(lvl)))
        elif id == ConduitPower.ID:
            vs.append(f64(ConduitPower().multiplier(lvl)))
        elif id == MiningFatigue.ID:
            vs.append(f64(MiningFatigue().multiplier(lvl)))
        elif id == Strength.ID:
            vs.append(f64(Strength().multiplier(lvl)))
        elif id == Weakness.ID:
            vs.append(f64(Weakness().multiplier(lvl)))
        elif id == Resistance.ID:
            vs.append(f64(Resistance().multiplier(PoisonDamageSource(), lvl)))
            vs.append(f64(Resistance().multiplier(_NotResisted(), lvl)))
    return String(",").join(vs)


def _source[S: DamageSource](s: S) -> String:
    return String(
        t"{b01(s.reduced_by_resistance())},{b01(s.reduced_by_armour())},"
        t"{b01(s.fire())},{b01(s.ignore_totem())}"
    )


def test_effects_match_dragonfly() raises:
    var n = 0
    for line in read_lines("test/data/world/defs.txt"):
        var p = line.split("\t")
        if p[0] == "effect":
            var id = Int(p[1])
            assert_true(VanillaEffects.contains(id))
            assert_equal(b01(VanillaEffects.lasting(id).value()), String(p[3]))
            var c = VanillaEffects.rgba(id).value()
            assert_equal(String(t"{c.r},{c.g},{c.b},{c.a}"), String(p[4]))
            n += 1
        elif p[0] == "effect_colour":
            var spec = p[1].split(";")
            var effects = List[Effect]()
            if spec[0].byte_length() > 0:
                var ids = spec[0].split(",")
                for i in range(len(ids)):
                    effects.append(
                        _by_id(Int(ids[i]), String(spec[1][byte = i : i + 1]))
                    )
            var r = resulting_colour(effects)
            var c = r[0]
            assert_equal(
                String(t"{c.r},{c.g},{c.b},{c.a},{b01(r[1])}"), String(p[2])
            )
        elif p[0] == "effect_tick":
            var e: Effect
            if p[1] == "lasting":
                e = new(Speed(), 2, SECOND * 3)
            elif p[1] == "infinite":
                e = new_infinite(Speed(), 1)
            else:
                e = new_instant(InstantHealth(), 3)
            for _ in range(3):
                e = e.tick_duration()
            assert_equal(
                String(t"{e.duration()}\t{e.tick()}\t{e.level()}\t")
                + b01(e.infinite()),
                String("\t").join(p[2:]),
            )
        elif p[0] == "effect_mult":
            assert_equal(_mult(Int(p[1])), String(p[2]), String(p[1]))
        elif p[0] == "damage_source":
            var got: String
            if p[1] == "PoisonDamageSource":
                got = _source(PoisonDamageSource())
            elif p[1] == "InstantDamageSource":
                got = _source(InstantDamageSource())
            elif p[1] == "WitherDamageSource":
                got = _source(WitherDamageSource())
            else:
                continue
            assert_equal(got, String(p[2]), String(p[1]))
    assert_equal(n, 28)
    assert_equal(len(VanillaEffects.ids()), 28)
    assert_false(VanillaEffects.contains(28))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
