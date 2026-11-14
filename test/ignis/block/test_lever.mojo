"""Tests for `Lever` (Go `lever.go`)."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from ignis.block.block import UseContext
from ignis.block.cube.direction import Direction
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.cube.rotation import Rotation
from ignis.block.register import VanillaBlocks
from ignis.mgl64 import Vec3
from ignis.world.world import World
from support.world_runtime import (
    RecordingViewer,
    VanillaWorld,
    new_vanilla_world,
)


def _viewing(mut w: World[VanillaWorld]) -> UInt64:
    var id = w.add_loader(0, RecordingViewer())
    w.load(id, 1000)
    return id


def _sounds(mut w: World[VanillaWorld], id: UInt64, sound_id: Int) -> Int:
    return w.viewer(id).count(String(t"sound {sound_id} "))


from ignis.block.lever import Lever
from ignis.world.sound.block import PowerOff, PowerOn


def test_activate_switches() raises:
    var w = new_vanilla_world()
    var id = _viewing(w)
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Lever(facing=Face.UP))
    var ctx = UseContext()
    assert_true(VanillaBlocks.activate(Lever.BASE_HASH, pos, Face.UP, w, ctx))
    assert_true(w.block_as[Lever](pos).value().powered)
    assert_equal(_sounds(w, id, PowerOn.SOUND_ID), 1)
    _ = VanillaBlocks.activate(Lever.BASE_HASH, pos, Face.UP, w, ctx)
    assert_false(w.block_as[Lever](pos).value().powered)
    assert_equal(_sounds(w, id, PowerOff.SOUND_ID), 1)


def test_use_on_block_attaches_to_the_face() raises:
    var w = new_vanilla_world()
    var ground = Pos(2, -62, 2)
    # On the floor, looking east (yaw -90): pointing west.
    var p = Lever().use_on_block(ground, Face.UP, Vec3(), Rotation(-90, 0), w)
    var l = p[0].block.get[Lever]().value()
    assert_true(p[0].pos == ground.side(Face.UP))
    assert_true(l.facing == Face.UP)
    assert_true(l.direction == Direction.WEST)
    # Looking north: pointing north.
    p = Lever().use_on_block(ground, Face.UP, Vec3(), Rotation(180, 0), w)
    assert_true(p[0].block.get[Lever]().value().direction == Direction.NORTH)
    # Without a solid face to hang on, nothing is placed.
    assert_equal(
        len(
            Lever().use_on_block(
                ground.side(Face.UP).side(Face.UP),
                Face.UP,
                Vec3(),
                Rotation(),
                w,
            )
        ),
        0,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
