from ignis.internal.rand import Rand
from ignis.world.settings import default_settings
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_default_settings() raises:
    var r = Rand(1, 2)
    var s = default_settings(r)
    assert_equal(s.name, "World")
    assert_true(s.time_cycle)
    assert_true(s.weather_cycle)
    assert_false(s.raining)
    assert_equal(s.tick_range, 6)
    assert_equal(String(s.default_game_mode), "survival")
    assert_equal(String(s.difficulty), "normal")
    # Rain and thunder times: (IntN(8400) + 600) * 20 ticks.
    assert_true(s.rain_time >= 600 * 20 and s.rain_time < 9000 * 20)
    assert_true(s.thunder_time >= 600 * 20 and s.thunder_time < 9000 * 20)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
