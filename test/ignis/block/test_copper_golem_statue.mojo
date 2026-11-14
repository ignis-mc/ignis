"""Tests for `CopperGolemStatue` activation (Go `copper_golem_statue.go`)."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from ignis.block.block import UseContext
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.register import VanillaBlocks
from ignis.item.stack import Stack
from ignis.mgl64 import Vec3
from support.activate import particles, sounds, viewing
from support.world_runtime import new_vanilla_world

from ignis.block.copper_golem_pose import CopperGolemPose
from ignis.block.copper_golem_statue import CopperGolemStatue
from ignis.item.stick import Stick


def test_poses_cycle_with_an_empty_hand() raises:
    var w = new_vanilla_world()
    var pos = Pos(2, -61, 2)
    w.set_block(pos, CopperGolemStatue(pose=CopperGolemPose.RUNNING))
    var ctx = UseContext()
    assert_true(
        VanillaBlocks.activate(
            CopperGolemStatue.BASE_HASH, pos, Face.UP, w, ctx
        )
    )
    assert_true(
        w.block_as[CopperGolemStatue](pos).value().pose == CopperGolemPose.STAR
    )
    _ = VanillaBlocks.activate(
        CopperGolemStatue.BASE_HASH, pos, Face.UP, w, ctx
    )
    assert_true(
        w.block_as[CopperGolemStatue](pos).value().pose
        == CopperGolemPose.STANDING
    )
    var held = UseContext()
    held.held = Stack(Stick(), 1)
    assert_false(
        VanillaBlocks.activate(
            CopperGolemStatue.BASE_HASH, pos, Face.UP, w, held
        )
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
