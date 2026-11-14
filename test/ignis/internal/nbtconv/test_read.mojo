from ignis.internal.nbtconv.read import (
    get_bool,
    get_int16,
    get_int32,
    get_slice,
    get_string,
    get_uint8,
    tick_duration_int16,
)
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_present_values() raises:
    var t = Tree()
    var r = t.root()
    _ = t.put_byte(r, "b", 1)
    _ = t.put_short(r, "s", 7)
    _ = t.put_int(r, "i", -3)
    _ = t.put_string(r, "x", "hi")
    _ = t.put_list(r, "l")
    assert_true(get_bool(t, r, "b"))
    assert_equal(get_uint8(t, r, "b"), 1)
    assert_equal(get_int16(t, r, "s"), 7)
    assert_equal(tick_duration_int16(t, r, "s"), 350)
    assert_equal(get_int32(t, r, "i"), -3)
    assert_equal(get_string(t, r, "x"), "hi")
    assert_true(get_slice(t, r, "l"))


def test_missing_or_mistyped_values_are_zero() raises:
    var t = Tree()
    var r = t.root()
    _ = t.put_int(r, "i", 5)
    assert_equal(get_int16(t, r, "i"), 0)
    assert_equal(get_int32(t, r, "missing"), 0)
    assert_equal(get_string(t, r, "i"), "")
    assert_false(get_bool(t, r, "i"))
    assert_false(Bool(get_slice(t, r, "i")))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
