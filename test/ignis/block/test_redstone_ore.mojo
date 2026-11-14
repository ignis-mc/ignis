"""Tests for `RedstoneOre` activation (Go `redstone_ore.go`)."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from ignis.block.block import UseContext
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.register import VanillaBlocks
from ignis.item.stack import Stack
from ignis.mgl64 import Vec3
from support.activate import particles, sounds, viewing
from support.world_runtime import new_vanilla_world

from ignis.block.redstone_ore import RedstoneOre
from ignis.world.particle.block import Dust


def test_activate_lights_without_using() raises:
    var w = new_vanilla_world()
    var id = viewing(w)
    var pos = Pos(2, -61, 2)
    w.set_block(pos, RedstoneOre())
    var sneak = UseContext()
    sneak.sneaking = True
    assert_false(
        VanillaBlocks.activate(RedstoneOre.BASE_HASH, pos, Face.UP, w, sneak)
    )
    assert_false(w.block_as[RedstoneOre](pos).value().lit)
    var ctx = UseContext()
    # Go returns false so the held item is still used.
    assert_false(
        VanillaBlocks.activate(RedstoneOre.BASE_HASH, pos, Face.UP, w, ctx)
    )
    assert_true(w.block_as[RedstoneOre](pos).value().lit)
    assert_equal(particles(w, id, Dust.PARTICLE_ID), 5)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
