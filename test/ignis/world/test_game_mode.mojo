from ignis.world.game_mode import (
    GAME_MODE_ADVENTURE,
    GAME_MODE_CREATIVE,
    GAME_MODE_SPECTATOR,
    GAME_MODE_SURVIVAL,
    game_mode_by_id,
    game_mode_by_name,
)
from std.testing import TestSuite, assert_false, assert_true


def test_flags() raises:
    assert_true(GAME_MODE_CREATIVE.allows_flying())
    assert_false(GAME_MODE_SURVIVAL.allows_flying())
    assert_false(GAME_MODE_ADVENTURE.allows_editing())
    assert_false(GAME_MODE_SPECTATOR.has_collision())
    assert_false(GAME_MODE_SPECTATOR.visible())
    assert_true(GAME_MODE_CREATIVE.creative_inventory())


def test_lookup() raises:
    assert_true(game_mode_by_id(1).value() == GAME_MODE_CREATIVE)
    assert_false(game_mode_by_id(4))
    assert_true(game_mode_by_name("spectator").value() == GAME_MODE_SPECTATOR)
    assert_true(game_mode_by_name("2").value() == GAME_MODE_ADVENTURE)
    assert_false(game_mode_by_name("hardcore"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
