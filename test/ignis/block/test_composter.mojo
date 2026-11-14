"""Tests for `Composter` (Go `composter.go`)."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from ignis.block.block import UseContext
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.register import VanillaBlocks
from ignis.item.stack import Stack
from ignis.mgl64 import Vec3
from support.activate import particles, sounds, viewing
from support.world_runtime import new_vanilla_world

from ignis.block.composter import Composter
from ignis.item.bone_meal import BoneMeal
from ignis.item.inventory.inventory import Inventory
from ignis.item.pumpkin_pie import PumpkinPie
from ignis.item.stick import Stick
from ignis.world.particle.block import BoneMeal as BoneMealParticle
from ignis.world.sound.block import (
    ComposterEmpty,
    ComposterFillLayer,
    ComposterReady,
)


def test_fill_ready_and_empty() raises:
    var w = new_vanilla_world()
    var id = viewing(w)
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Composter())
    # Pumpkin pie always adds a layer (compost chance 1).
    for i in range(1, 8):
        var ctx = UseContext()
        ctx.held = Stack(PumpkinPie(), 4)
        assert_true(
            VanillaBlocks.activate(Composter.BASE_HASH, pos, Face.UP, w, ctx)
        )
        assert_equal(ctx.count_sub, 1)
        assert_equal(w.block_as[Composter](pos).value().level, i)
    assert_equal(sounds(w, id, ComposterFillLayer.SOUND_ID), 7)
    assert_equal(particles(w, id, BoneMealParticle.PARTICLE_ID), 7)
    # Level 7 takes nothing more and turns ready a second later.
    var full = UseContext()
    full.held = Stack(PumpkinPie(), 4)
    assert_false(
        VanillaBlocks.activate(Composter.BASE_HASH, pos, Face.UP, w, full)
    )
    for _ in range(21):
        w.advance_tick()
    assert_equal(w.block_as[Composter](pos).value().level, 8)
    assert_equal(sounds(w, id, ComposterReady.SOUND_ID), 1)
    # Collecting the bone meal empties it.
    var ctx = UseContext()
    assert_true(
        VanillaBlocks.activate(Composter.BASE_HASH, pos, Face.UP, w, ctx)
    )
    assert_equal(w.block_as[Composter](pos).value().level, 0)
    var drops = w.take_item_drops()
    assert_equal(len(drops), 1)
    assert_true(drops[0].stack.item_as[BoneMeal]())
    assert_equal(sounds(w, id, ComposterEmpty.SOUND_ID), 1)


def test_not_compostable() raises:
    var w = new_vanilla_world()
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Composter())
    var ctx = UseContext()
    ctx.held = Stack(Stick(), 1)
    assert_false(
        VanillaBlocks.activate(Composter.BASE_HASH, pos, Face.UP, w, ctx)
    )
    assert_equal(w.block_as[Composter](pos).value().level, 0)


def test_hoppers() raises:
    var w = new_vanilla_world()
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Composter(level=6))
    var hopper = Inventory(5)
    hopper.set_item(0, Stack(Stick(), 2))
    hopper.set_item(3, Stack(PumpkinPie(), 2))
    var c = w.block_as[Composter](pos).value()
    # Only a hopper facing down feeds it.
    assert_false(c.insert_item(hopper, Face.EAST, pos, w))
    assert_true(c.insert_item(hopper, Face.DOWN, pos, w))
    assert_equal(hopper.item(3).count(), 1)
    assert_equal(hopper.item(0).count(), 2)
    c = w.block_as[Composter](pos).value()
    assert_equal(c.level, 7)
    assert_false(c.extract_item(hopper, pos, w))
    w.set_block(pos, Composter(level=8))
    c = w.block_as[Composter](pos).value()
    var below = Inventory(5)
    assert_true(c.extract_item(below, pos, w))
    assert_true(below.item(0).item_as[BoneMeal]())
    assert_equal(w.block_as[Composter](pos).value().level, 0)
    # Breaking a full composter drops bone meal.
    Composter(level=8).on_break(pos, w, True)
    assert_equal(len(w.take_item_drops()), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
