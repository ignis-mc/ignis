from ignis.item.creative.category import Category
from std.testing import TestSuite, assert_equal


def test_values() raises:
    assert_equal(Category.CONSTRUCTION.uint8(), 1)
    assert_equal(Category.NATURE.uint8(), 2)
    assert_equal(Category.EQUIPMENT.uint8(), 3)
    assert_equal(Category.ITEMS.uint8(), 4)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
