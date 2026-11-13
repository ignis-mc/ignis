from ignis.world.game_mode import (
    GAME_MODE_ADVENTURE,
    GAME_MODE_CREATIVE,
    GAME_MODE_SPECTATOR,
    GAME_MODE_SURVIVAL,
    game_mode_by_id,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_capabilities_match_go() raises:
    assert_true(GAME_MODE_SURVIVAL.allows_editing())
    assert_true(GAME_MODE_SURVIVAL.allows_taking_damage())
    assert_false(GAME_MODE_SURVIVAL.allows_flying())
    assert_true(GAME_MODE_CREATIVE.creative_inventory())
    assert_true(GAME_MODE_CREATIVE.allows_flying())
    assert_false(GAME_MODE_CREATIVE.allows_taking_damage())
    assert_true(GAME_MODE_CREATIVE.instant_portal_travel())
    assert_false(GAME_MODE_ADVENTURE.allows_editing())
    assert_true(GAME_MODE_ADVENTURE.allows_interaction())
    assert_false(GAME_MODE_SPECTATOR.has_collision())
    assert_false(GAME_MODE_SPECTATOR.visible())
    assert_false(GAME_MODE_SPECTATOR.allows_interaction())
    assert_true(GAME_MODE_SPECTATOR.allows_flying())


def test_by_id() raises:
    assert_true(game_mode_by_id(1).value() == GAME_MODE_CREATIVE)
    assert_false(game_mode_by_id(4))
    assert_equal(String(GAME_MODE_SPECTATOR), "spectator")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
