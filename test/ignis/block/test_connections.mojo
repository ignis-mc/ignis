from ignis.block.connections import (
    Connections,
    FireConnections,
    all_connections,
    all_fire_connections,
)
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.glass_pane import GlassPane
from ignis.block.iron_bars import IronBars
from ignis.block.nether_brick_fence import NetherBrickFence
from ignis.block.register import VanillaBlocks, vanilla_block_registry
from ignis.block.stone import Stone
from ignis.block.string import StringBlock
from ignis.block.wood_fence import WoodFence
from ignis.block.wood_fence_gate import WoodFenceGate
from ignis.block.wood_type import WoodType
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.block_state import Properties
from std.memory import ArcPointer
from std.testing import TestSuite, assert_equal, assert_true
from support.map_source import MapSource, derive_vectors
from support.world_runtime import new_vanilla_world


def test_connections() raises:
    var all = all_connections()
    assert_equal(len(all), 16)
    for i in range(16):
        assert_equal(Int(all[i].uint8()), i)
    var c = Connections(north=True, east=False, south=True, west=False)
    assert_equal(Int(c.uint8()), 5)
    assert_equal(
        String(c.properties(Properties())),
        "minecraft:connection_east=b:0,minecraft:connection_north=b:1,"
        + "minecraft:connection_south=b:1,minecraft:connection_west=b:0",
    )


def test_fire_connections() raises:
    var all = all_fire_connections()
    assert_equal(len(all), 32)
    for i in range(32):
        assert_equal(Int(all[i].uint8()), i)
    assert_true(FireConnections(bits=16).up)
    assert_equal(len(FireConnections().properties(Properties())), 5)


def _place(mut src: MapSource, pos: Pos, option: Int):
    # The neighbour options of derive.go.
    if option == 1:
        src.set(pos, Stone())
    elif option == 2:
        src.set(pos, WoodFence(wood=WoodType.OAK))
    elif option == 3:
        src.set(pos, NetherBrickFence())
    elif option == 4:
        src.set(pos, GlassPane())
    elif option == 5:
        src.set(pos, WoodFenceGate(wood=WoodType.OAK))
    elif option == 6:
        src.set(pos, StringBlock())


def _sources(br: ArcPointer[BasicBlockRegistry], row: List[Int]) -> MapSource:
    var src = MapSource(br)
    var sides = [Face.NORTH, Face.EAST, Face.SOUTH, Face.WEST]
    for i in range(4):
        _place(src, Pos(0, 0, 0).side(sides[i]), row[i + 1])
    return src^


def test_derive_state_matches_dragonfly() raises:
    var br = ArcPointer(vanilla_block_registry())
    var centre = Pos(0, 0, 0)
    var kinds = [
        "wood_fence",
        "nether_brick_fence",
        "glass_pane",
        "iron_bars",
        "string",
    ]
    for kind in kinds:
        var rows = derive_vectors(kind)
        assert_equal(len(rows), 7 * 7 * 7 * 7)
        for row in rows:
            var src = _sources(br, row)
            var got: UInt8
            if kind == "wood_fence":
                got = (
                    WoodFence(wood=WoodType.OAK)
                    .derive_state(centre, src)
                    .connections.uint8()
                )
            elif kind == "nether_brick_fence":
                got = (
                    NetherBrickFence()
                    .derive_state(centre, src)
                    .connections.uint8()
                )
            elif kind == "glass_pane":
                got = GlassPane().derive_state(centre, src).connections.uint8()
            elif kind == "iron_bars":
                got = IronBars().derive_state(centre, src).connections.uint8()
            else:
                got = (
                    StringBlock().derive_state(centre, src).connections.uint8()
                )
            if Int(got) != row[5]:
                raise Error(
                    t"{kind} {row[1]} {row[2]} {row[3]} {row[4]}: got {got},"
                    t" want {row[5]}"
                )


def test_fence_connects_when_a_neighbour_is_placed() raises:
    var w = new_vanilla_world()
    var pos = Pos(5, -61, 5)
    w.set_block(pos, WoodFence(wood=WoodType.OAK))
    w.set_block(pos.side(Face.EAST), Stone())
    w.tick(w.next_deadline_ms())
    var f = w.block_as[WoodFence](pos).value()
    assert_true(f.connections.east)
    assert_true(not f.connections.north)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
