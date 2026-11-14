from ignis.item.colour import Colour
from ignis.item.optional_colour import OptionalColour, optional_colours
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_optional_colour() raises:
    var all = optional_colours()
    assert_equal(len(all), 17)
    assert_true(all[0] == OptionalColour.NONE)
    assert_false(Bool(OptionalColour.NONE.colour()))
    assert_equal(OptionalColour.NONE.prepend("candle"), "candle")
    var red = OptionalColour(Colour.RED)
    assert_equal(Int(red.uint8()), 15)
    assert_true(red.colour().value() == Colour.RED)
    assert_equal(red.prepend("candle_cake"), "red_candle_cake")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
