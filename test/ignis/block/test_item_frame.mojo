from ignis.block.item_frame import ItemFrame
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_true


def test_nbt_round_trip() raises:
    var f = ItemFrame(rotations=3, drop_chance=0.5, glowing=True)
    var t = Tree()
    f.encode_nbt(t, t.root())
    assert_equal(t.get_string(t.root(), "id"), "GlowItemFrame")
    assert_equal(t.get_byte(t.root(), "ItemRotation"), 3)
    var back = ItemFrame(glowing=True).decode_nbt(t, t.root())
    assert_equal(back.rotations, 3)
    assert_equal(back.drop_chance, 0.5)


def test_plain_frame_id() raises:
    var t = Tree()
    ItemFrame().encode_nbt(t, t.root())
    assert_equal(t.get_string(t.root(), "id"), "ItemFrame")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
