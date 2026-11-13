from ignis.item.beef import Beef
from ignis.item.item import item_info
from ignis.item.shears import Shears
from ignis.world.item import ItemInfo
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_item_info() raises:
    assert_true(item_info(Beef()) == ItemInfo())
    var s = item_info(Shears())
    assert_equal(s.max_count, 1)
    assert_equal(s.max_durability, 238)
    assert_false(s.repairable)
    assert_false(s.air)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
