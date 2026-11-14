from ignis.item.recipe.shape import new_shape
from std.testing import TestSuite, assert_equal


def test_shape() raises:
    var s = new_shape(3, 2)
    assert_equal(s.width(), 3)
    assert_equal(s.height(), 2)
    assert_equal(String(s), "3x2")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
