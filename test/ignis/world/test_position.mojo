from ignis.world.position import ChunkPos, SubChunkPos
from std.testing import TestSuite, assert_equal


def test_positions() raises:
    var c = ChunkPos(3, -2)
    assert_equal(c.x(), 3)
    assert_equal(c.z(), -2)
    assert_equal(String(c), "(3, -2)")
    var s = SubChunkPos(1, -4, 2)
    assert_equal(s.y(), -4)
    assert_equal(String(s), "(1, -4, 2)")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
