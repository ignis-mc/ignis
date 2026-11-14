from ignis.world.biome import RGBA
from ignis.world.biome.plains import Plains
from std.testing import TestSuite, assert_equal, assert_true


def test_plains() raises:
    var p = Plains()
    assert_equal(p.encode_biome(), 1)
    assert_equal(p.string(), "plains")
    assert_equal(p.temperature(), 0.8)
    assert_true(p.water_colour() == RGBA(0x44, 0xAF, 0xF5, 0xA5))
    assert_equal(len(p.tags()), 5)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
