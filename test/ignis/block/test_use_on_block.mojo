from ignis.block.cube.axis import Axis
from ignis.block.cube.direction import Direction
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.cube.rotation import Rotation
from ignis.block.hash import AnyBlock
from ignis.block.log import Log
from ignis.block.planks import Planks
from ignis.block.slab import Slab
from ignis.block.stairs import Stairs
from ignis.block.stone import Stone
from ignis.block.wood_door import WoodDoor
from ignis.block.wood_trapdoor import WoodTrapdoor
from ignis.mgl64 import Vec3
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.world_runtime import VanillaWorld, new_vanilla_world
from ignis.world.world import World


def _world() raises -> World[VanillaWorld]:
    var w = new_vanilla_world()
    w.set_block(GROUND, Stone())
    return w^


# A stone block on the flat world's grass (top block y = -62), so that its
# sides are free.
comptime GROUND = Pos(0, -61, 0)
# Facing south: yaw 0.
comptime SOUTH = Rotation(0, 0)


def test_log_axis_from_face() raises:
    var w = _world()
    var up = Log().use_on_block(GROUND, Face.UP, Vec3(0.5, 1, 0.5), SOUTH, w)
    assert_equal(len(up), 1)
    assert_true(up[0].pos == GROUND.side(Face.UP))
    assert_true(Log.from_hash(up[0].block.state).axis == Axis.Y)
    var east = Log().use_on_block(
        GROUND, Face.EAST, Vec3(1, 0.5, 0.5), SOUTH, w
    )
    assert_true(Log.from_hash(east[0].block.state).axis == Axis.X)
    assert_true(east[0].pos == GROUND.side(Face.EAST))


def test_stairs_facing_and_upside_down() raises:
    var w = _world()
    var s = Stairs(block=AnyBlock(Planks()))
    var low = s.use_on_block(GROUND, Face.NORTH, Vec3(0.5, 0.2, 0), SOUTH, w)
    var b = Stairs.from_hash(low[0].block.state)
    assert_true(b.facing == SOUTH.direction())
    assert_false(b.upside_down)
    var high = s.use_on_block(GROUND, Face.NORTH, Vec3(0.5, 0.8, 0), SOUTH, w)
    assert_true(Stairs.from_hash(high[0].block.state).upside_down)


def test_slab_top_bottom_and_double() raises:
    var w = _world()
    var s = Slab(block=AnyBlock(Stone()))
    var bottom = s.use_on_block(GROUND, Face.UP, Vec3(0.5, 1, 0.5), SOUTH, w)
    assert_false(Slab.from_hash(bottom[0].block.state).top)
    var top = s.use_on_block(GROUND, Face.NORTH, Vec3(0.5, 0.7, 0), SOUTH, w)
    assert_true(Slab.from_hash(top[0].block.state).top)
    # A bottom slab clicked on its top becomes a double slab in place.
    var p = GROUND.side(Face.UP)
    w.set_block(p, Slab.from_hash(bottom[0].block.state))
    var d = s.use_on_block(p, Face.UP, Vec3(0.5, 0.5, 0.5), SOUTH, w)
    assert_true(d[0].pos == p)
    assert_true(Slab.from_hash(d[0].block.state).double)


def test_trapdoor_faces_the_user() raises:
    var w = _world()
    var t = WoodTrapdoor().use_on_block(
        GROUND, Face.NORTH, Vec3(0.5, 0.9, 0), SOUTH, w
    )
    var b = WoodTrapdoor.from_hash(t[0].block.state)
    assert_true(b.facing == SOUTH.direction().opposite())
    assert_true(b.top)


def test_door_places_two_halves_on_solid_ground() raises:
    var w = _world()
    var d = WoodDoor().use_on_block(
        GROUND, Face.UP, Vec3(0.5, 1, 0.5), SOUTH, w
    )
    assert_equal(len(d), 2)
    assert_false(WoodDoor.from_hash(d[0].block.state).top)
    assert_true(WoodDoor.from_hash(d[1].block.state).top)
    assert_true(d[1].pos == d[0].pos.side(Face.UP))
    assert_true(d[0].ignore_bbox)
    # Not on the side of a block.
    var side = WoodDoor().use_on_block(
        GROUND, Face.NORTH, Vec3(0.5, 0.5, 0), SOUTH, w
    )
    assert_equal(len(side), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
