"""Tests for `ignis.block.liquid`, `water` and `lava`: the worlds of
`interop/behaviour/liquids.go`, ticked and compared with Dragonfly."""

from std.testing import TestSuite, assert_equal

from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.flower import Flower
from ignis.block.flower_type import FlowerType
from ignis.block.lava import Lava
from ignis.block.planks import Planks
from ignis.block.slab import Slab
from ignis.block.stone import Stone
from ignis.block.torch import Torch
from ignis.block.water import Water
from ignis.block.wood_fence import WoodFence
from ignis.block.hash import AnyBlock
from ignis.world.world import World

from support.behaviour_vectors import (
    BehaviourVectors,
    assert_region_equal,
    dump_region,
    expected_lines,
)
from support.world_runtime import VanillaWorld, new_vanilla_world

comptime _PATH = "test/data/behaviour/liquids.txt"
comptime _LO = Pos(-10, -63, -10)
comptime _HI = Pos(10, -55, 10)


def _water() -> Water:
    return Water(still=True, depth=8)


def _lava() -> Lava:
    return Lava(still=True, depth=8)


def _check(mut w: World[VanillaWorld], name: String) raises:
    var v = BehaviourVectors(_PATH)
    var tick = 0
    var drops = 0
    for cp in v.ticks(name):
        while tick < cp:
            w.advance_tick()
            drops += len(w.take_item_drops())
            tick += 1
        var got = dump_region(w, _LO, _HI, w.entity_count() + drops)
        assert_region_equal(
            got, expected_lines(v, name, cp), String(t"{name}@{cp}")
        )


def _world() raises -> World[VanillaWorld]:
    return new_vanilla_world(random_tick_speed=-1)


def test_water_flat() raises:
    var w = _world()
    w.set_liquid(Pos(0, -61, 0), _water())
    _check(w, "water_flat")


def test_lava_flat() raises:
    var w = _world()
    w.set_liquid(Pos(0, -61, 0), _lava())
    _check(w, "lava_flat")


def test_water_hole() raises:
    var w = _world()
    var air = w.block_registry()[].air_runtime_id()
    w.set_block_runtime_id(Pos(3, -62, 1), air)
    w.set_block_runtime_id(Pos(3, -63, 1), air)
    w.set_liquid(Pos(0, -61, 0), _water())
    _check(w, "water_hole")


def test_water_falls() raises:
    var w = _world()
    w.set_liquid(Pos(0, -56, 0), _water())
    _check(w, "water_falls")


def test_lava_meets_water() raises:
    var w = _world()
    w.set_liquid(Pos(0, -61, 0), _water())
    w.set_liquid(Pos(5, -61, 0), _lava())
    _check(w, "lava_meets_water")


def test_water_on_lava() raises:
    var w = _world()
    w.set_liquid(Pos(0, -61, 0), _lava())
    w.set_liquid(Pos(2, -59, 0), _water())
    _check(w, "water_on_lava")


def test_waterlogged() raises:
    var w = _world()
    w.set_liquid(Pos(0, -61, 0), _water())
    w.set_block(Pos(0, -61, 0), WoodFence())
    w.set_block(Pos(2, -61, 0), WoodFence())
    w.set_block(Pos(0, -61, 2), Slab(block=AnyBlock(Planks())))
    w.set_block(Pos(-2, -61, 0), Slab(block=AnyBlock(Planks()), top=True))
    _check(w, "waterlogged")


def test_water_removes() raises:
    var w = _world()
    w.set_block(Pos(1, -61, 0), Flower())
    w.set_block(Pos(0, -61, 1), Flower(type=FlowerType.POPPY))
    w.set_block(Pos(-1, -61, 0), Stone())
    w.set_block(Pos(0, -61, -2), Torch(facing=Face.DOWN))
    w.set_liquid(Pos(0, -61, 0), _water())
    _check(w, "water_removes")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
