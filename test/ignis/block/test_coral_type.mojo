from ignis.block.coral_type import CoralType, coral_types
from ignis.item.colour import Colour
from std.testing import TestSuite, assert_equal, assert_true


def test_coral_type() raises:
    var all = coral_types()
    assert_equal(len(all), 5)
    var colours = [
        Colour.BLUE,
        Colour.PINK,
        Colour.PURPLE,
        Colour.RED,
        Colour.YELLOW,
    ]
    for i in range(5):
        assert_true(all[i].colour() == colours[i])
    assert_equal(String(CoralType.HORN), "horn")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
