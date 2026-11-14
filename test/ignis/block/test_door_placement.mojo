"""Tests for door hinges (Go `door_placement.go` `doorHingeRight`)."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from ignis.block.copper_door import CopperDoor
from ignis.block.cube.direction import Direction
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.cube.rotation import Rotation
from ignis.block.door_placement import door_hinge_right, door_placement_position
from ignis.block.glass import Glass
from ignis.block.hash import AnyBlock
from ignis.block.oxidation_type import OxidationType
from ignis.block.stone import Stone
from ignis.block.wood_door import WoodDoor
from ignis.mgl64 import Vec3
from support.world_runtime import new_vanilla_world

comptime GROUND = Pos(8, -62, 8)
"""A grass block; doors go on top of it."""


def test_hinge_left_by_default() raises:
    var w = new_vanilla_world()
    var pos = GROUND.side(Face.UP)
    assert_false(door_hinge_right(w, pos, Direction.NORTH))


def test_hinge_right_towards_more_solid_blocks() raises:
    var w = new_vanilla_world()
    var pos = GROUND.side(Face.UP)
    # Facing north, the right side is east.
    w.set_block(pos.side(Face.EAST), Stone())
    assert_true(door_hinge_right(w, pos, Direction.NORTH))
    # One solid block each side: left.
    w.set_block(pos.side(Face.WEST), Stone())
    assert_false(door_hinge_right(w, pos, Direction.NORTH))
    # Two on the right beat one on the left.
    w.set_block(pos.side(Face.EAST).side(Face.UP), Stone())
    assert_true(door_hinge_right(w, pos, Direction.NORTH))


def test_transparent_blocks_do_not_count() raises:
    var w = new_vanilla_world()
    var pos = GROUND.side(Face.UP)
    # Glass diffuses no light, so Go skips it.
    w.set_block(pos.side(Face.EAST), Glass())
    assert_false(door_hinge_right(w, pos, Direction.NORTH))


def test_door_on_the_left_puts_the_hinge_right() raises:
    var w = new_vanilla_world()
    var pos = GROUND.side(Face.UP)
    w.set_block(pos.side(Face.WEST), WoodDoor(facing=Direction.NORTH))
    assert_true(door_hinge_right(w, pos, Direction.NORTH))
    # A door on both sides: no hinge change from doors.
    w.set_block(pos.side(Face.EAST), WoodDoor(facing=Direction.NORTH))
    assert_false(door_hinge_right(w, pos, Direction.NORTH))


def test_placement_needs_a_solid_block_below() raises:
    var w = new_vanilla_world()
    var door = AnyBlock(WoodDoor())
    var at = door_placement_position(w, GROUND, Face.UP, door)
    assert_true(at.value() == GROUND.side(Face.UP))
    # Clicking the side of the ground block places nothing.
    assert_false(door_placement_position(w, GROUND, Face.NORTH, door))


def test_copper_door_uses_the_hinge() raises:
    var w = new_vanilla_world()
    var pos = GROUND.side(Face.UP)
    # Facing west (yaw 90), the right side is north.
    w.set_block(pos.side(Face.NORTH), Stone())
    var p = CopperDoor(oxidation=OxidationType.WEATHERED).use_on_block(
        GROUND, Face.UP, Vec3(0.5, 1, 0.5), Rotation(90, 0), w
    )
    assert_equal(len(p), 2)
    var lower = p[0].block.get[CopperDoor]().value()
    var upper = p[1].block.get[CopperDoor]().value()
    assert_true(lower.facing == Direction.WEST)
    assert_true(lower.right)
    assert_true(upper.right)
    assert_true(upper.top)
    assert_true(upper.oxidation == OxidationType.WEATHERED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
