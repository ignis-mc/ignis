"""Tests for `CopperDoor` activation (Go `copper_door.go`)."""

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


from ignis.block.copper_door import CopperDoor
from ignis.block.oxidation_type import OxidationType
from ignis.world.sound.block import DoorClose, DoorOpen


def test_activate_opens_both_halves() raises:
    var w = new_vanilla_world()
    var id = _viewing(w)
    var lower = Pos(2, -61, 2)
    var upper = lower.side(Face.UP)
    var d = CopperDoor(oxidation=OxidationType.EXPOSED, waxed=True)
    w.set_block(lower, d)
    var top = d
    top.top = True
    w.set_block(upper, top)
    var ctx = UseContext()
    assert_true(
        VanillaBlocks.activate(CopperDoor.BASE_HASH, lower, Face.UP, w, ctx)
    )
    var l = w.block_as[CopperDoor](lower).value()
    assert_true(l.open)
    assert_true(l.waxed)
    assert_true(l.oxidation == OxidationType.EXPOSED)
    assert_true(w.block_as[CopperDoor](upper).value().open)
    assert_equal(_sounds(w, id, DoorOpen.SOUND_ID), 1)
    _ = VanillaBlocks.activate(CopperDoor.BASE_HASH, upper, Face.UP, w, ctx)
    assert_false(w.block_as[CopperDoor](lower).value().open)
    assert_equal(_sounds(w, id, DoorClose.SOUND_ID), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
