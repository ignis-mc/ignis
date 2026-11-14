from ignis.item.register import VanillaItems
from ignis.item.shears import Shears
from ignis.item.stick import Stick
from ignis.item.tool import TYPE_SHEARS, ToolInfo
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


def test_tool_dispatch() raises:
    var t = VanillaItems.tool(Shears.BASE_HASH, Shears().hash(), 0)
    assert_true(t.tool_type == TYPE_SHEARS)
    assert_equal(t.efficiency, 1.5)
    var none = VanillaItems.tool(Stick.BASE_HASH, Stick().hash(), 0)
    assert_true(none == ToolInfo.none())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
