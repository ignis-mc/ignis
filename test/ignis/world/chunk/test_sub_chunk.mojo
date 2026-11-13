from ignis.world.chunk.sub_chunk import SubChunk
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_layers_and_blocks() raises:
    var s = SubChunk(100)
    assert_true(s.empty())
    assert_equal(s.block(1, 2, 3, 0), 100)
    s.set_block(1, 2, 3, 1, 5)
    assert_equal(len(s.layers()), 2)
    # Layer 0 holds only air, but there are two layers.
    assert_false(s.empty())
    assert_equal(s.block(1, 2, 3, 1), 5)
    assert_equal(s.block(1, 2, 3, 0), 100)
    assert_equal(s.block(1, 2, 3, 4), 100)


def test_compact_drops_air_layers() raises:
    var s = SubChunk(100)
    s.set_block(0, 0, 0, 1, 5)
    s.set_block(0, 0, 0, 1, 100)
    s.compact()
    assert_equal(len(s.layers()), 0)
    assert_true(s.empty())


def test_equals() raises:
    var a = SubChunk(100)
    var b = SubChunk(100)
    assert_true(a.equals(b))
    a.set_block(0, 0, 0, 0, 5)
    b.set_block(0, 0, 0, 0, 5)
    assert_true(a.equals(b))
    b.set_block(1, 0, 0, 0, 5)
    assert_false(a.equals(b))
    assert_false(SubChunk(1).equals(SubChunk(2)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
