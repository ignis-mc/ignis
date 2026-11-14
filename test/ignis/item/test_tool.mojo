from ignis.item.shears import Shears
from ignis.item.tool import (
    TOOL_TIER_DIAMOND,
    TOOL_TIER_WOOD,
    TYPE_NONE,
    TYPE_SHEARS,
    ToolNone,
)
from std.testing import TestSuite, assert_equal, assert_true


def test_tool_types() raises:
    assert_true(Shears().tool_type() == TYPE_SHEARS)
    assert_equal(Shears().harvest_level(), 1)
    assert_equal(Shears().base_mining_efficiency(0), 1.5)
    assert_true(ToolNone().tool_type() == TYPE_NONE)
    assert_equal(String(TYPE_SHEARS), "shears")
    assert_equal(TYPE_NONE.t, -1)


def test_tiers_match_go() raises:
    assert_equal(TOOL_TIER_WOOD.harvest_level, 1)
    assert_equal(TOOL_TIER_WOOD.durability, 59)
    assert_equal(TOOL_TIER_DIAMOND.durability, 1561)
    assert_equal(TOOL_TIER_DIAMOND.base_mining_efficiency, 8.0)
    assert_equal(TOOL_TIER_DIAMOND.name, "diamond")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
