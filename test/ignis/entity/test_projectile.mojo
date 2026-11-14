"""Tests for `ignis.entity.projectile` and the projectile, TNT, orb and
firework types: the flights of `interop/entities/main.go`, compared with
Dragonfly every tick (positions and velocities to the bit) and the blocks
they leave."""

from std.testing import TestSuite

from ignis.block.campfire import Campfire
from ignis.block.cube.pos import Pos
from ignis.block.fire import Fire
from ignis.block.stone import Stone
from ignis.entity.arrow import Arrow
from ignis.entity.egg import Egg
from ignis.entity.ender_pearl import EnderPearl
from ignis.entity.experience_orb import ExperienceOrb
from ignis.entity.firework import Firework
from ignis.entity.lingering_potion import LingeringPotion
from ignis.entity.snowball import Snowball
from ignis.entity.splash_potion import SplashPotion
from ignis.entity.tnt import TNT
from ignis.item.firework import Firework as FireworkItem
from ignis.mgl64 import Vec3
from ignis.world.world import World

from support.entity_vectors import (
    assert_lines_equal,
    block_lines,
    load_lines,
    record,
    spawn,
)
from support.world_runtime import VanillaWorld, new_vanilla_world

comptime _PATH = "test/data/entities/flights.txt"
comptime _START = Vec3(0.5, -59, 0.5)


def _world(wall: Bool = False) raises -> World[VanillaWorld]:
    var w = new_vanilla_world(random_tick_speed=-1)
    for cx in range(-1, 2):
        for cz in range(-1, 2):
            _ = w.block(Pos(cx << 4, 0, cz << 4))
    if wall:
        for y in range(-61, -55):
            for z in range(-2, 3):
                w.set_block(Pos(8, y, z), Stone())
    return w^


def _check(mut w: World[VanillaWorld], name: String, ticks: Int) raises:
    var got = List[String]()
    for tick in range(1, ticks + 1):
        w.advance_tick()
        _ = w.take_item_drops()
        got += record(w, name, tick)
    got += block_lines(
        w, name + "\tend\tblock", Pos(-6, -63, -6), Pos(12, -55, 6)
    )
    assert_lines_equal(got, load_lines(_PATH, name), name)


def test_snowball() raises:
    var w = _world()
    spawn(w, _START, Vec3(0.6, 0.3, 0.1), Snowball())
    _check(w, "snowball", 40)


def test_egg() raises:
    var w = _world(wall=True)
    spawn(w, _START, Vec3(0.9, 0.1, 0), Egg())
    _check(w, "egg", 40)


def test_ender_pearl() raises:
    var w = _world()
    spawn(w, _START, Vec3(-0.4, 0.5, 0.3), EnderPearl())
    _check(w, "ender_pearl", 40)


def test_arrow_wall() raises:
    var w = _world(wall=True)
    spawn(w, _START, Vec3(1.5, 0.2, 0.05), Arrow())
    _check(w, "arrow_wall", 60)


def test_arrow_ground() raises:
    var w = _world()
    spawn(w, _START, Vec3(0.8, 0.6, -0.3), Arrow())
    _check(w, "arrow_ground", 60)


def test_splash_water() raises:
    var w = _world()
    w.set_block(Pos(4, -61, 0), Fire())
    w.set_block(Pos(5, -61, 0), Fire())
    w.set_block(Pos(4, -61, 1), Campfire())
    spawn(w, _START, Vec3(0.45, 0.2, 0.02), SplashPotion())
    _check(w, "splash_water", 40)


def test_lingering() raises:
    var w = _world()
    spawn(w, _START, Vec3(0.3, 0.2, 0), LingeringPotion())
    _check(w, "lingering", 40)


def test_tnt() raises:
    var w = _world()
    spawn(w, Vec3(0.5, -57, 0.5), Vec3(0.05, 0.1, -0.02), TNT(2000))
    _check(w, "tnt", 30)


def test_xp_orb() raises:
    var w = _world()
    spawn(w, _START, Vec3(0.2, 0.3, -0.1), ExperienceOrb(7))
    _check(w, "xp_orb", 40)


def test_firework() raises:
    var w = _world()
    # Go's duration is 2 s plus up to 600 ms; 30 ticks stay below it.
    spawn(
        w,
        _START,
        Vec3(0.01, 0.05, 0),
        Firework(FireworkItem(duration=2000), 2300),
    )
    _check(w, "firework", 30)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
