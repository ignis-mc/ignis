"""Tests for `DragonEgg` activation (Go `dragon_egg.go`)."""

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
from ignis.block.dragon_egg import DragonEgg
from ignis.world.particle.block import DragonEggTeleport


def test_activate_teleports_nearby() raises:
    var w = new_vanilla_world()
    var id = viewing(w)
    var pos = Pos(8, -61, 8)
    w.set_block(pos, DragonEgg())
    var ctx = UseContext()
    assert_true(
        VanillaBlocks.activate(DragonEgg.BASE_HASH, pos, Face.UP, w, ctx)
    )
    assert_true(w.block_as[Air](pos))
    assert_equal(particles(w, id, DragonEggTeleport.PARTICLE_ID), 1)
    var found = 0
    for dx in range(-15, 16):
        for dy in range(-7, 8):
            for dz in range(-15, 16):
                if w.block_as[DragonEgg](pos.add(Pos(dx, dy, dz))):
                    found += 1
    assert_equal(found, 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
