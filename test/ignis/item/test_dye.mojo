from ignis.item.colour import Colour
from ignis.item.dye import Dye
from std.testing import TestSuite, assert_equal, assert_true


def test_dye_encoding() raises:
    assert_equal(Dye().encode_item().name, "minecraft:white_dye")
    assert_equal(
        Dye(colour=Colour.LIGHT_GREY).encode_item().name,
        "minecraft:light_gray_dye",
    )


def test_dye_hash_round_trip() raises:
    var all = Dye.all_items()
    assert_equal(len(all), 16)
    for d in all:
        assert_true(Dye.from_hash(d.hash()) == d)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
