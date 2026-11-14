from ignis.internal.fnv import fnv1_64, fnv1a_32, fnv1a_64
from std.testing import TestSuite, assert_equal


def test_fnv1_64() raises:
    # Published FNV-1 64 values.
    assert_equal(fnv1_64("".as_bytes()), 0xCBF29CE484222325)
    assert_equal(fnv1_64("a".as_bytes()), 0xAF63BD4C8601B7BE)
    assert_equal(fnv1_64("foobar".as_bytes()), 0x340D8765A4DDA9C2)


def test_fnv1a_32() raises:
    # Published FNV-1a 32 values.
    assert_equal(fnv1a_32("".as_bytes()), 0x811C9DC5)
    assert_equal(fnv1a_32("a".as_bytes()), 0xE40C292C)
    assert_equal(fnv1a_32("foobar".as_bytes()), 0xBF9CF968)


def test_fnv1a_64() raises:
    # Published FNV-1a 64 values.
    assert_equal(fnv1a_64("".as_bytes()), 0xCBF29CE484222325)
    assert_equal(fnv1a_64("a".as_bytes()), 0xAF63DC4C8601EC8C)
    assert_equal(fnv1a_64("foobar".as_bytes()), 0x85944171F73967E8)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
