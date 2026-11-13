from ignis.world.chunk.heightmap import HeightMap
from std.testing import TestSuite, assert_equal


def test_heightmap() raises:
    var h = HeightMap()
    assert_equal(len(h), 256)
    h.set(3, 4, 10)
    assert_equal(h.at(3, 4), 10)
    assert_equal(h[3 * 16 + 4], 10)
    assert_equal(h.highest_neighbour(2, 4), 10)
    assert_equal(h.highest_neighbour(3, 5), 10)
    assert_equal(h.highest_neighbour(3, 4), 0)
    assert_equal(h.highest_neighbour(0, 0), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
