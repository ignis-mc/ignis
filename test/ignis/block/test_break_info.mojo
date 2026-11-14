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
from ignis.block.break_info import (
    BreakContext,
    NEVER_BREAKS_MS,
    break_duration_ms,
    breaks_instantly,
)
from ignis.block.dirt import Dirt
from ignis.block.grass import Grass
from ignis.block.stone import Stone
from ignis.block.short_grass import ShortGrass
from ignis.item.tool import ToolInfo
from ignis.item.tool import TOOL_TIER_DIAMOND, TOOL_TIER_WOOD


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


def test_break_duration() raises:
    var hand = ToolInfo.none()
    var ctx = BreakContext()
    # Vanilla by hand: dirt 0.75 s, grass block 0.9 s, stone 7.5 s (the
    # hand cannot harvest it, so it counts 100 instead of 30).
    assert_equal(break_duration_ms(Dirt().break_info(), hand, 0, ctx), 750)
    assert_equal(break_duration_ms(Grass().break_info(), hand, 0, ctx), 900)
    assert_equal(break_duration_ms(Stone().break_info(), hand, 0, ctx), 7500)
    # A wooden pickaxe (efficiency 2) harvests stone: 1.5 / 2 * 30 ticks.
    var wood = ToolInfo(TYPE_PICKAXE, TOOL_TIER_WOOD.harvest_level, 2)
    assert_equal(break_duration_ms(Stone().break_info(), wood, 0, ctx), 1150)
    # Efficiency III adds 3*3+1 to the speed: 1.5 * 30 / 12 = 3.75 -> 4 ticks.
    assert_equal(break_duration_ms(Stone().break_info(), wood, 3, ctx), 200)
    # In the air without flying: five times slower.
    var air = BreakContext()
    air.airborne = True
    assert_equal(break_duration_ms(Dirt().break_info(), hand, 0, air), 3750)
    air.flying = True
    assert_equal(break_duration_ms(Dirt().break_info(), hand, 0, air), 750)
    # Haste II: speed * 1.4 and damage * 1.2^2.
    var haste = BreakContext()
    haste.haste_level = 2
    assert_equal(break_duration_ms(Dirt().break_info(), hand, 0, haste), 400)
    # Mining fatigue I: speed * 0.3 and damage * 0.7.
    var fatigue = BreakContext()
    fatigue.mining_fatigue_level = 1
    assert_equal(break_duration_ms(Dirt().break_info(), hand, 0, fatigue), 3600)
    # Under water without Aqua Affinity: five times slower.
    var water = BreakContext()
    water.underwater = True
    assert_equal(break_duration_ms(Dirt().break_info(), hand, 0, water), 3750)
    # Zero hardness breaks instantly; non-breakable blocks never.
    assert_equal(break_duration_ms(ShortGrass().break_info(), hand, 0, ctx), 0)
    assert_true(breaks_instantly(ShortGrass().break_info()))
    assert_equal(break_duration_ms(None, hand, 0, ctx), NEVER_BREAKS_MS)
    _ = TOOL_TIER_DIAMOND


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
