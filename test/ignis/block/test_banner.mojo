from ignis.block.banner import Banner, invert_colour, invert_colour_id
from ignis.block.banner_pattern_layer import BannerPatternLayer
from ignis.block.banner_pattern_type import BannerPatternType
from ignis.item.colour import Colour
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_true


def test_invert_colour() raises:
    assert_equal(invert_colour(Colour.WHITE), 15)
    assert_equal(invert_colour(Colour.BLACK), 0)
    assert_true(invert_colour_id(15) == Colour.WHITE)


def test_encode_item_meta_is_inverted_colour() raises:
    assert_equal(Banner(colour=Colour.RED).encode_item().meta, 1)


def test_nbt_round_trip() raises:
    var b = Banner(
        colour=Colour.LIME,
        patterns=[
            BannerPatternLayer(BannerPatternType.CREEPER, Colour.BLACK),
            BannerPatternLayer(BannerPatternType.BORDER, Colour.WHITE),
        ],
        illager=True,
    )
    var t = Tree()
    b.encode_nbt(t, t.root())
    assert_equal(t.get_string(t.root(), "id"), "Banner")
    assert_equal(t.get_int(t.root(), "Base"), 10)
    assert_equal(t.get_int(t.root(), "Type"), 1)
    assert_equal(t.length(t.get_list(t.root(), "Patterns")), 2)
    var back = Banner().decode_nbt(t, t.root())
    assert_true(back.colour == Colour.LIME)
    assert_true(back.illager)
    assert_equal(len(back.patterns), 2)
    assert_true(back.patterns[0] == b.patterns[0])
    assert_true(back.patterns[1] == b.patterns[1])


def test_item_nbt_without_base_keeps_colour() raises:
    var t = Tree()
    _ = t.put_int(t.root(), "Type", 0)
    var back = Banner(colour=Colour.BLUE).decode_nbt(t, t.root())
    assert_true(back.colour == Colour.BLUE)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
