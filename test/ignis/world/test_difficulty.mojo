from ignis.world.difficulty import (
    DIFFICULTY_EASY,
    DIFFICULTY_HARD,
    DIFFICULTY_NORMAL,
    DIFFICULTY_PEACEFUL,
    difficulty_by_id,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_values_match_go() raises:
    assert_true(DIFFICULTY_PEACEFUL.food_regenerates())
    assert_false(DIFFICULTY_EASY.food_regenerates())
    assert_equal(DIFFICULTY_PEACEFUL.starvation_health_limit(), 20.0)
    assert_equal(DIFFICULTY_EASY.starvation_health_limit(), 10.0)
    assert_equal(DIFFICULTY_NORMAL.starvation_health_limit(), 2.0)
    assert_equal(DIFFICULTY_HARD.starvation_health_limit(), -1.0)
    assert_equal(DIFFICULTY_HARD.fire_spread_increase(), 21)
    assert_equal(DIFFICULTY_NORMAL.fire_spread_increase(), 14)


def test_by_id() raises:
    assert_true(difficulty_by_id(3).value() == DIFFICULTY_HARD)
    assert_false(difficulty_by_id(-1))
    assert_equal(String(DIFFICULTY_NORMAL), "normal")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
