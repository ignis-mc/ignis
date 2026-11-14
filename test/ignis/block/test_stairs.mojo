"""Tests for `Stairs` corners against Dragonfly's `calculateCorner`
(`test/data/behaviour/derive_state.txt` from `interop/behaviour`)."""

from std.memory import ArcPointer
from std.testing import TestSuite, assert_equal, assert_true

from ignis.block.cube.direction import Direction
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.cube.rotation import Rotation
from ignis.block.hash import AnyBlock
from ignis.block.planks import Planks
from ignis.block.register import VanillaBlocks, vanilla_block_registry
from ignis.block.stairs import Stairs
from ignis.block.stairs_corner import StairsCorner
from ignis.block.stone import Stone
from ignis.block.wood_type import WoodType
from ignis.mgl64 import Vec3
from support.map_source import MapSource, derive_vectors
from support.world_runtime import new_vanilla_world

comptime SIDES = [Face.NORTH, Face.EAST, Face.SOUTH, Face.WEST]


def _oak(facing: Direction) -> Stairs:
    return Stairs(block=AnyBlock(Planks(wood=WoodType.OAK)), facing=facing)


def _place(mut src: MapSource, pos: Pos, option: Int):
    # Options 1 to 4 face north, east, south and west (derive.go).
    var dirs = [
        Direction.NORTH,
        Direction.EAST,
        Direction.SOUTH,
        Direction.WEST,
    ]
    if option >= 1 and option <= 4:
        src.set(pos, _oak(dirs[option - 1]))
    elif option == 5:
        src.set(pos, Stairs(block=AnyBlock(Stone()), facing=Direction.NORTH))


def test_derive_state_matches_dragonfly() raises:
    var br = ArcPointer(vanilla_block_registry())
    var rows = derive_vectors("stairs")
    assert_equal(len(rows), 4 * 6 * 6 * 6 * 6)
    var centre = Pos(0, 0, 0)
    for row in rows:
        var src = MapSource(br)
        for i in range(4):
            _place(src, centre.side(materialize[SIDES]()[i]), row[i + 1])
        var d = _oak(Direction(row[0])).derive_state(centre, src)
        if Int(d.corner.uint8()) != row[5]:
            raise Error(
                t"stairs {row[0]} {row[1]} {row[2]} {row[3]} {row[4]}: got"
                t" {d.corner.uint8()}, want {row[5]}"
            )


def test_use_on_block_derives_the_corner() raises:
    var w = new_vanilla_world()
    var pos = Pos(3, -61, 3)
    # Stairs facing east in front of north-facing stairs: outer right.
    w.set_block(pos.side(Face.NORTH), _oak(Direction.EAST))
    var p = _oak(Direction.NORTH).use_on_block(
        pos.side(Face.DOWN), Face.UP, Vec3(0.5, 1, 0.5), Rotation(180, 0), w
    )
    assert_equal(len(p), 1)
    var s = p[0].block.get[Stairs]().value()
    assert_true(s.facing == Direction.NORTH)
    assert_true(s.corner == StairsCorner.OUTER_RIGHT)
    assert_equal(
        VanillaBlocks.derive_state(
            Stairs.BASE_HASH, _oak(Direction.NORTH).hash(), pos, w
        ).state,
        s.hash(),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
