from ignis.block.note import Note
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_true


def test_note_item() raises:
    assert_equal(Note().encode_item().name, "minecraft:noteblock")
    assert_equal(Note.all_items()[0].pitch, 24)
    assert_equal(Note().fuel_info().duration, 15000)


def test_note_nbt_round_trip() raises:
    var tag = Tree()
    Note(pitch=7, powered=True).encode_nbt(tag, tag.root())
    assert_equal(tag.get_byte(tag.root(), "note"), 7)
    assert_equal(tag.get_byte(tag.root(), "powered"), 1)
    var back = Note().decode_nbt(tag, tag.root())
    assert_equal(back.pitch, 7)
    assert_true(back.powered)
    # Missing keys decode to Go's zero values.
    var empty = Tree()
    assert_equal(Note(pitch=3).decode_nbt(empty, empty.root()).pitch, 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
