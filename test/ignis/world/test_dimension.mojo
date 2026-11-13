from ignis.world.dimension import END, NETHER, OVERWORLD, dimension_by_id
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_vanilla_dimensions() raises:
    assert_equal(OVERWORLD.range().min(), -64)
    assert_equal(OVERWORLD.range().max(), 319)
    assert_equal(NETHER.range().max(), 127)
    assert_equal(END.range().max(), 255)
    assert_true(NETHER.water_evaporates())
    assert_equal(NETHER.lava_spread_duration_ms(), 250)
    assert_equal(OVERWORLD.lava_spread_duration_ms(), 1500)
    assert_true(OVERWORLD.weather_cycle() and OVERWORLD.time_cycle())
    assert_false(END.weather_cycle() or END.time_cycle())
    assert_equal(String(NETHER), "Nether")


def test_dimension_by_id() raises:
    assert_true(dimension_by_id(1).value() == NETHER)
    assert_false(dimension_by_id(3))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
