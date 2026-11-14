from ignis.internal.rand import Rand
from ignis.world.settings import default_settings
from ignis.world.weather import advance_weather, set_raining, set_thunder
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_timers_toggle_weather() raises:
    var r = Rand(1, 2)
    var s = default_settings(r)
    set_raining(s, False, 100)
    assert_equal(s.rain_time, 2)
    advance_weather(s, r)
    assert_false(s.raining)
    advance_weather(s, r)
    # Rain starts and lasts 600-1199 seconds.
    assert_true(s.raining)
    assert_true(s.rain_time >= 600 * 20 and s.rain_time < 1200 * 20)
    set_thunder(s, False, 50)
    advance_weather(s, r)
    assert_true(s.thundering)
    assert_true(s.thunder_time >= 180 * 20 and s.thunder_time < 800 * 20)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
