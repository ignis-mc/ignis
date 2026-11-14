"""Tests for `CopperTrapdoor` activation (Go `copper_trapdoor.go`)."""

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


from ignis.block.copper_trapdoor import CopperTrapdoor
from ignis.block.oxidation_type import OxidationType
from ignis.world.sound.block import TrapdoorClose, TrapdoorOpen


def test_activate_toggles() raises:
    var w = new_vanilla_world()
    var id = _viewing(w)
    var pos = Pos(2, -61, 2)
    w.set_block(pos, CopperTrapdoor(oxidation=OxidationType.OXIDISED))
    var ctx = UseContext()
    assert_true(
        VanillaBlocks.activate(CopperTrapdoor.BASE_HASH, pos, Face.UP, w, ctx)
    )
    var t = w.block_as[CopperTrapdoor](pos).value()
    assert_true(t.open)
    assert_true(t.oxidation == OxidationType.OXIDISED)
    assert_equal(_sounds(w, id, TrapdoorOpen.SOUND_ID), 1)
    _ = VanillaBlocks.activate(CopperTrapdoor.BASE_HASH, pos, Face.UP, w, ctx)
    assert_false(w.block_as[CopperTrapdoor](pos).value().open)
    assert_equal(_sounds(w, id, TrapdoorClose.SOUND_ID), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
