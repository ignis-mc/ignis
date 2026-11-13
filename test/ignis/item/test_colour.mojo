from ignis.item.colour import Colour, colours
from std.testing import TestSuite, assert_equal


def test_names() raises:
    var want = [
        "white",
        "orange",
        "magenta",
        "light_blue",
        "yellow",
        "lime",
        "pink",
        "gray",
        "light_gray",
        "cyan",
        "purple",
        "blue",
        "brown",
        "green",
        "red",
        "black",
    ]
    var all = colours()
    assert_equal(len(all), 16)
    for i in range(16):
        assert_equal(Int(all[i].uint8()), i)
        assert_equal(String(all[i]), want[i])
    assert_equal(Colour.LIGHT_GREY.silver_string(), "silver")
    assert_equal(Colour.GREY.silver_string(), "gray")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
