from ignis.block.cube.pos import Pos
from ignis.mgl64 import Vec3
from ignis.world.position import (
    ChunkPos,
    SubChunkPos,
    chunk_pos_from_block_pos,
    chunk_pos_from_vec3,
)
from std.testing import TestSuite, assert_equal


def test_positions() raises:
    var c = ChunkPos(3, -2)
    assert_equal(c.x(), 3)
    assert_equal(c.z(), -2)
    assert_equal(String(c), "(3, -2)")
    var s = SubChunkPos(1, -4, 2)
    assert_equal(s.y(), -4)
    assert_equal(String(s), "(1, -4, 2)")


def test_chunk_pos_from() raises:
    assert_equal(chunk_pos_from_vec3(Vec3(15.9, 0, -0.1)), ChunkPos(0, -1))
    assert_equal(chunk_pos_from_vec3(Vec3(16, 0, -16)), ChunkPos(1, -1))
    assert_equal(chunk_pos_from_vec3(Vec3(-16.5, 0, 0)), ChunkPos(-2, 0))
    assert_equal(chunk_pos_from_block_pos(Pos(-1, 5, 31)), ChunkPos(-1, 1))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
