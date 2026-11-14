from ignis.block.cube.face import Face
from ignis.block.hopper import Hopper
from minecraft.nbt.nbt import TAG_END
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_nbt_round_trip() raises:
    var h = Hopper(facing=Face.NORTH, custom_name="Sorter", transfer_cooldown=4)
    var t = Tree()
    h.encode_nbt(t, t.root())
    var items = t.get_list(t.root(), "Items")
    assert_equal(t.length(items), 0)
    assert_equal(t.elem_type(items), TAG_END)
    assert_equal(t.get_int(t.root(), "TransferCooldown"), 4)
    assert_equal(t.get_string(t.root(), "CustomName"), "Sorter")
    var back = Hopper(facing=Face.NORTH).decode_nbt(t, t.root())
    assert_true(back == h)
    assert_equal(back.custom_name, "Sorter")
    assert_equal(back.transfer_cooldown, 4)


def test_no_custom_name_key_when_unnamed() raises:
    var t = Tree()
    Hopper().encode_nbt(t, t.root())
    assert_false(t.has(t.root(), "CustomName"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
