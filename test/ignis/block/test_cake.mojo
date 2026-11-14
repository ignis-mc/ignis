"""Tests for `Cake` activation (Go `cake.go`)."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from ignis.block.block import UseContext
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.register import VanillaBlocks
from ignis.item.stack import Stack
from ignis.mgl64 import Vec3
from support.activate import particles, sounds, viewing
from support.world_runtime import new_vanilla_world

from ignis.block.air import Air
from ignis.block.cake import Cake
from ignis.block.candle import Candle
from ignis.item.colour import Colour
from ignis.item.optional_colour import OptionalColour
from ignis.world.sound.entity import Burp


def test_bites_until_gone() raises:
    var w = new_vanilla_world()
    var id = viewing(w)
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Cake())
    for i in range(1, 7):
        var ctx = UseContext()
        assert_true(
            VanillaBlocks.activate(Cake.BASE_HASH, pos, Face.UP, w, ctx)
        )
        assert_equal(ctx.food, 2)
        assert_equal(ctx.saturation, 0.4)
        assert_equal(w.block_as[Cake](pos).value().bites, i)
    var ctx = UseContext()
    _ = VanillaBlocks.activate(Cake.BASE_HASH, pos, Face.UP, w, ctx)
    assert_true(w.block_as[Air](pos))
    assert_equal(sounds(w, id, Burp.SOUND_ID), 7)


def test_candle_goes_on_a_whole_cake() raises:
    var w = new_vanilla_world()
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Cake())
    var ctx = UseContext()
    var colour = OptionalColour(Colour.LIME)
    ctx.held = Stack(Candle(colour=colour), 3)
    assert_true(VanillaBlocks.activate(Cake.BASE_HASH, pos, Face.UP, w, ctx))
    assert_equal(ctx.count_sub, 1)
    assert_equal(ctx.food, 0)
    var c = w.block_as[Cake](pos).value()
    assert_true(c.candle)
    assert_true(c.candle_colour == colour)
    assert_equal(c.bites, 0)
    # Eating drops the candle.
    var eat = UseContext()
    _ = VanillaBlocks.activate(Cake.BASE_HASH, pos, Face.UP, w, eat)
    c = w.block_as[Cake](pos).value()
    assert_false(c.candle)
    assert_equal(c.bites, 1)
    var drops = w.take_item_drops()
    assert_equal(len(drops), 1)
    assert_true(drops[0].stack.item_as[Candle]().value().colour == colour)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
