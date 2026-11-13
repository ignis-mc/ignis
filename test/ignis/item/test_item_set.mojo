from ignis.item.beef import Beef
from ignis.item.item_set import ItemSet
from ignis.item.stick import Stick
from ignis.world.item import ItemRegistry
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_contains() raises:
    comptime S = ItemSet[Beef, Stick]
    assert_true(S.contains(Beef.BASE_HASH))
    assert_true(S.contains(Stick.BASE_HASH))
    assert_false(S.contains(0))


def test_register_all() raises:
    var reg = ItemRegistry.load("resources/vanilla_items.nbt")
    ItemSet[Beef, Stick].register_all(reg)
    assert_equal(len(reg.items()), 3)
    assert_true(reg.item_by_name("minecraft:cooked_beef", 0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
