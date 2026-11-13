from ignis.block.register import vanilla_block_registry
from ignis.block.stone import Stone
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.chunk.chunk import Chunk
from ignis.world.dimension import NETHER
from std.collections import Dict
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.world_vectors import (
    biome_chunk,
    flat_chunk,
    load_vectors,
    new_chunk,
    simple_chunk,
)


def _height_map(br: BasicBlockRegistry, mut c: Chunk) -> String:
    var hm = c.height_map(br)
    var s = String()
    for i in range(len(hm)):
        if i > 0:
            s += ","
        s += String(hm[i])
    return s^


def test_height_maps_match_dragonfly() raises:
    var br = vanilla_block_registry()
    var v = load_vectors()
    var empty = new_chunk(br)
    assert_equal(_height_map(br, empty), v["empty.height_map"])
    var simple = simple_chunk(br)
    assert_equal(_height_map(br, simple), v["simple.height_map"])
    var flat = flat_chunk(br)
    assert_equal(_height_map(br, flat), v["flat_fixed.height_map"])
    var biomes = biome_chunk(br)
    assert_equal(_height_map(br, biomes), v["biomes.height_map"])


def test_highest_filled_sub_chunk_matches_dragonfly() raises:
    var br = vanilla_block_registry()
    var v = load_vectors()
    assert_equal(
        String(new_chunk(br).highest_filled_sub_chunk()),
        v["empty.highest_filled"],
    )
    assert_equal(
        String(simple_chunk(br).highest_filled_sub_chunk()),
        v["simple.highest_filled"],
    )
    assert_equal(
        String(flat_chunk(br).highest_filled_sub_chunk()),
        v["flat_fixed.highest_filled"],
    )


def test_blocks_and_layers() raises:
    var br = vanilla_block_registry()
    var c = new_chunk(br)
    var stone = br.block_runtime_id(Stone())
    assert_equal(c.block(1, -64, 1, 0), br.air())
    c.set_block(1, -64, 1, 0, stone)
    c.set_block(15, 319, 15, 1, stone)
    assert_equal(c.block(1, -64, 1, 0), stone)
    assert_equal(c.block(15, 319, 15, 1), stone)
    assert_equal(c.block(15, 319, 15, 0), br.air())
    # Air on a missing layer creates nothing.
    c.set_block(0, 0, 0, 3, br.air())
    assert_equal(len(c.sub_chunk(0).layers()), 0)
    assert_equal(c.highest_block(1, 1), -64)
    assert_equal(c.highest_block(15, 15), -64)
    assert_equal(c.highest_block(0, 0), -64)
    c.set_block(0, 100, 0, 0, stone)
    assert_equal(c.highest_block(0, 0), 100)
    assert_equal(c.highest_light_blocker(br, 0, 0), 100)
    assert_equal(c.sub_index(100), 10)
    assert_equal(c.sub_y(10), 96)


def test_height_map_is_recalculated_after_changes() raises:
    var br = vanilla_block_registry()
    var c = new_chunk(br)
    assert_equal(c.height_map(br).at(2, 3), -64)
    c.set_block(2, 10, 3, 0, br.block_runtime_id(Stone()))
    assert_equal(c.height_map(br).at(2, 3), 11)


def test_biome_section() raises:
    var br = vanilla_block_registry()
    var c = new_chunk(br)
    var sec = List[UInt32](length=64, fill=4)
    sec[1 * 16 + 2 * 4 + 3] = 9
    c.set_biome_section(20, sec)
    # Quart (1, 2, 3) covers x 4-7, y 8-11 (of the section at 16), z 12-15.
    assert_equal(c.biome(5, 25, 13), 9)
    assert_equal(c.biome(5, 25, 11), 4)
    assert_equal(c.biomes()[c.sub_index(20)].bits_per_index(), 1)
    c.set_biome_section(40, List[UInt32](length=64, fill=4))
    assert_equal(c.biomes()[c.sub_index(40)].bits_per_index(), 0)
    assert_equal(c.biome(0, 40, 0), 4)


def test_equals_and_copy() raises:
    var br = vanilla_block_registry()
    var a = simple_chunk(br)
    var b = a.copy()
    assert_true(a.equals(b))
    b.set_block(0, 200, 0, 0, br.block_runtime_id(Stone()))
    assert_false(a.equals(b))
    assert_false(new_chunk(br).equals(Chunk(br, NETHER.range())))


def test_compact() raises:
    var br = vanilla_block_registry()
    var c = new_chunk(br)
    var stone = br.block_runtime_id(Stone())
    c.set_block(0, 0, 0, 0, stone)
    c.set_block(0, 0, 0, 0, br.air())
    c.compact()
    assert_equal(len(c.sub_chunk(0).layers()), 0)
    assert_true(c.sub_chunk(0).empty())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
