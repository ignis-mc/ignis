from ignis.world.chunk.palette import (
    Palette,
    padded,
    palette_size_for,
    uint32s,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_sizes() raises:
    assert_equal(palette_size_for(1), 0)
    assert_equal(palette_size_for(2), 1)
    assert_equal(palette_size_for(5), 3)
    assert_equal(palette_size_for(64), 6)
    assert_equal(palette_size_for(65), 8)
    assert_equal(palette_size_for(257), 16)
    assert_true(padded(3) and padded(5) and padded(6))
    assert_false(padded(4) or padded(8))
    assert_equal(uint32s(0), 0)
    assert_equal(uint32s(1), 128)
    assert_equal(uint32s(3), 410)
    assert_equal(uint32s(5), 683)
    assert_equal(uint32s(6), 820)
    assert_equal(uint32s(16), 2048)


def test_add_and_index() raises:
    var p = Palette(0, [7])
    var r = p.add(9)
    assert_equal(r[0], 1)
    assert_true(r[1])
    assert_equal(p.size(), 1)
    r = p.add(10)
    assert_true(r[1])
    assert_equal(p.size(), 2)
    r = p.add(11)
    assert_false(r[1])
    assert_equal(p.index(10), 2)
    assert_equal(p.index(10), 2)
    assert_equal(p.index(99), -1)
    assert_equal(p.value(3), 11)
    assert_equal(len(p), 4)


def _double(v: UInt32) -> UInt32:
    return v * 2


def test_replace() raises:
    var p = Palette(1, [1, 2])
    _ = p.index(2)
    p.replace(_double)
    assert_equal(p.values(), [2, 4])
    assert_equal(p.index(2), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
