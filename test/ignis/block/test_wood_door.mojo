"""Tests for `WoodDoor` activation and placement (Go `wood_door.go`)."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from ignis.block.block import UseContext
from ignis.block.cube.direction import Direction
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.cube.rotation import Rotation
from ignis.block.hash import AnyBlock
from ignis.block.register import VanillaBlocks
from ignis.block.wood_door import WoodDoor
from ignis.block.wood_type import WoodType
from ignis.mgl64 import Vec3
from ignis.world.sound.block import DoorClose, DoorOpen
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


def test_activate_opens_both_halves() raises:
    var w = new_vanilla_world()
    var id = _viewing(w)
    var lower = Pos(2, -61, 2)
    var upper = lower.side(Face.UP)
    var d = WoodDoor(wood=WoodType.BIRCH, facing=Direction.EAST)
    w.set_block(lower, d)
    var top = d
    top.top = True
    w.set_block(upper, top)
    var ctx = UseContext()
    # Activating the upper half opens the lower one too.
    assert_true(
        VanillaBlocks.activate(WoodDoor.BASE_HASH, upper, Face.UP, w, ctx)
    )
    assert_true(w.block_as[WoodDoor](lower).value().open)
    assert_true(w.block_as[WoodDoor](upper).value().open)
    assert_equal(w.viewer(id).count(String(t"sound {DoorOpen.SOUND_ID} ")), 1)
    assert_true(
        VanillaBlocks.activate(WoodDoor.BASE_HASH, lower, Face.UP, w, ctx)
    )
    assert_false(w.block_as[WoodDoor](lower).value().open)
    assert_false(w.block_as[WoodDoor](upper).value().open)
    assert_equal(w.viewer(id).count(String(t"sound {DoorClose.SOUND_ID} ")), 1)


def test_use_on_block_places_both_halves() raises:
    var w = new_vanilla_world()
    var ground = Pos(4, -62, 4)
    var p = WoodDoor(wood=WoodType.OAK).use_on_block(
        ground, Face.UP, Vec3(0.5, 1, 0.5), Rotation(90, 0), w
    )
    assert_equal(len(p), 2)
    var lower = p[0].block.get[WoodDoor]().value()
    var upper = p[1].block.get[WoodDoor]().value()
    assert_true(p[0].pos == ground.side(Face.UP))
    assert_true(lower.facing == Direction.WEST)
    assert_false(lower.top)
    assert_true(upper.top)
    assert_false(lower.right)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
