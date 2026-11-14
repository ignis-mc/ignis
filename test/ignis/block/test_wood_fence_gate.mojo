"""Tests for `WoodFenceGate` (Go `wood_fence_gate.go`)."""

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


from ignis.block.cobblestone import Cobblestone
from ignis.block.hash import AnyBlock
from ignis.block.stone import Stone
from ignis.block.wall import Wall
from ignis.block.wood_fence_gate import WoodFenceGate
from ignis.block.wood_type import WoodType
from ignis.world.sound.block import FenceGateClose, FenceGateOpen


def test_activate_swings_away_from_the_user() raises:
    var w = new_vanilla_world()
    var id = _viewing(w)
    var pos = Pos(2, -61, 2)
    w.set_block(
        pos, WoodFenceGate(wood=WoodType.DARK_OAK, facing=Direction.NORTH)
    )
    var ctx = UseContext()
    # A user looking south (yaw 0) faces the gate's back: it flips.
    ctx.user_rot = Rotation(0, 0)
    assert_true(
        VanillaBlocks.activate(WoodFenceGate.BASE_HASH, pos, Face.UP, w, ctx)
    )
    var g = w.block_as[WoodFenceGate](pos).value()
    assert_true(g.open)
    assert_true(g.facing == Direction.SOUTH)
    assert_equal(_sounds(w, id, FenceGateOpen.SOUND_ID), 1)
    # Closing never flips.
    ctx.user_rot = Rotation(180, 0)
    _ = VanillaBlocks.activate(WoodFenceGate.BASE_HASH, pos, Face.UP, w, ctx)
    g = w.block_as[WoodFenceGate](pos).value()
    assert_false(g.open)
    assert_true(g.facing == Direction.SOUTH)
    assert_equal(_sounds(w, id, FenceGateClose.SOUND_ID), 1)
    # Opening while looking the way it faces keeps the facing.
    ctx.user_rot = Rotation(0, 0)
    _ = VanillaBlocks.activate(WoodFenceGate.BASE_HASH, pos, Face.UP, w, ctx)
    assert_true(
        w.block_as[WoodFenceGate](pos).value().facing == Direction.SOUTH
    )


def test_lowered_between_walls() raises:
    var w = new_vanilla_world()
    var pos = Pos(2, -61, 2)
    w.set_block(pos.side(Face.EAST), Wall(block=AnyBlock(Cobblestone())))
    var p = WoodFenceGate().use_on_block(
        pos.side(Face.DOWN), Face.UP, Vec3(0.5, 1, 0.5), Rotation(180, 0), w
    )
    var g = p[0].block.get[WoodFenceGate]().value()
    assert_true(g.facing == Direction.NORTH)
    assert_true(g.lowered)
    w.set_block(pos, g)
    w.set_block(pos.side(Face.EAST), Stone())
    w.tick(w.next_deadline_ms())
    assert_false(w.block_as[WoodFenceGate](pos).value().lowered)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
