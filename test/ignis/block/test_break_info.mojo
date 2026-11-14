from ignis.block.break_info import (
    ALWAYS_HARVESTABLE,
    HARVEST_LEVEL_IRON,
    NEVER_HARVESTABLE,
    PICKAXE_HARVESTABLE,
    SHEARS_EFFECTIVE,
    SWORD_EFFECTIVE,
    new_break_info,
    pickaxe_harvestable_from,
)
from ignis.item.shears import Shears
from ignis.item.tool import (
    TYPE_AXE,
    TYPE_NONE,
    TYPE_PICKAXE,
    TYPE_SHEARS,
    TYPE_SWORD,
    ToolNone,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_filters() raises:
    assert_true(ALWAYS_HARVESTABLE.matches(TYPE_NONE, 0))
    assert_true(ALWAYS_HARVESTABLE.matches(TYPE_SWORD, 4))
    assert_false(NEVER_HARVESTABLE.matches(TYPE_NONE, 0))
    assert_true(PICKAXE_HARVESTABLE.matches(TYPE_PICKAXE, 1))
    assert_false(PICKAXE_HARVESTABLE.matches(TYPE_AXE, 4))
    var iron = pickaxe_harvestable_from(HARVEST_LEVEL_IRON)
    assert_false(iron.matches(TYPE_PICKAXE, 2))
    assert_true(iron.matches(TYPE_PICKAXE, 3))
    var either = SWORD_EFFECTIVE | SHEARS_EFFECTIVE
    assert_true(either.matches(TYPE_SWORD, 1))
    assert_true(either.matches(TYPE_SHEARS, 1))
    assert_false(either.matches(TYPE_NONE, 0))


def test_break_info() raises:
    var b = new_break_info(1.5, PICKAXE_HARVESTABLE, PICKAXE_HARVESTABLE)
    assert_equal(b.blast_resistance, 1.5)
    assert_equal(b.with_blast_resistance(6).blast_resistance, 6.0)
    var xp = b.with_xp_drop_range(2, 5).xp_drops
    assert_equal(xp.min, 2)
    assert_equal(xp.max, 5)


def test_matches_tool() raises:
    assert_true(SHEARS_EFFECTIVE.matches_tool(Shears()))
    assert_false(PICKAXE_HARVESTABLE.matches_tool(Shears()))
    assert_true(ALWAYS_HARVESTABLE.matches_tool(ToolNone()))
    assert_false(PICKAXE_HARVESTABLE.matches_tool(ToolNone()))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
