from ignis.block.cube.range import Range
from std.testing import TestSuite, assert_equal


def test_range() raises:
    var r = Range(-64, 319)
    assert_equal(r.min(), -64)
    assert_equal(r.max(), 319)
    assert_equal(r.height(), 383)
    assert_equal(String(r), "[-64 319]")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
