from ignis.block.bed import Bed
from ignis.item.colour import Colour
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def test_nbt_round_trip() raises:
    var t = Tree()
    Bed(colour=Colour.CYAN).encode_nbt(t, t.root())
    assert_equal(t.get_byte(t.root(), "color"), 9)
    assert_true(Bed().decode_nbt(t, t.root()).colour == Colour.CYAN)


def test_invalid_colour_raises() raises:
    var t = Tree()
    _ = t.put_byte(t.root(), "color", 16)
    with assert_raises():
        _ = Bed().decode_nbt(t, t.root())


def test_encode_item() raises:
    var e = Bed(colour=Colour.RED).encode_item()
    assert_equal(e.name, "minecraft:bed")
    assert_equal(e.meta, 14)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
