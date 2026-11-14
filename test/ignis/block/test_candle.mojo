"""Tests for `Candle` activation (Go `candle.go`)."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from ignis.block.block import UseContext
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.register import VanillaBlocks
from ignis.item.stack import Stack
from ignis.mgl64 import Vec3
from support.activate import particles, sounds, viewing
from support.world_runtime import new_vanilla_world

from ignis.block.candle import Candle
from ignis.item.enchantment import FIRE_ASPECT_ID
from ignis.item.stack import Enchantment
from ignis.item.sword import Sword
from ignis.world.sound.block import Ignite


def test_fire_aspect_lights_it() raises:
    var w = new_vanilla_world()
    var id = viewing(w)
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Candle())
    var plain = UseContext()
    plain.held = Stack(Sword(), 1)
    assert_false(
        VanillaBlocks.activate(Candle.BASE_HASH, pos, Face.UP, w, plain)
    )
    var ctx = UseContext()
    ctx.held = Stack(Sword(), 1).with_forced_enchantments(
        [Enchantment(Int16(FIRE_ASPECT_ID), 1)]
    )
    assert_true(VanillaBlocks.activate(Candle.BASE_HASH, pos, Face.UP, w, ctx))
    assert_true(w.block_as[Candle](pos).value().lit)
    assert_equal(ctx.damage, 1)
    assert_equal(sounds(w, id, Ignite.SOUND_ID), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
