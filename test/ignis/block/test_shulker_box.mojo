from ignis.block.cube.face import Face
from ignis.block.shulker_box import ShulkerBox
from ignis.item.optional_colour import OptionalColour
from minecraft.nbt.nbt import TAG_END
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal


def test_shulker_box_item() raises:
    assert_equal(
        ShulkerBox().encode_item().name, "minecraft:undyed_shulker_box"
    )
    assert_equal(ShulkerBox().max_count(), 1)
    assert_equal(len(ShulkerBox.all_items()), 17)


def test_shulker_box_nbt_round_trip() raises:
    var tag = Tree()
    var r = tag.root()
    ShulkerBox(facing=Face.EAST, custom_name="Loot").encode_nbt(tag, r)
    assert_equal(tag.get_string(r, "id"), "ShulkerBox")
    assert_equal(tag.length(tag.get_list(r, "Items")), 0)
    assert_equal(tag.elem_type(tag.get_list(r, "Items")), TAG_END)
    assert_equal(Int(tag.get_byte(r, "facing")), Int(Face.EAST))
    var back = ShulkerBox().decode_nbt(tag, r)
    assert_equal(Int(back.facing), Int(Face.EAST))
    assert_equal(back.custom_name, "Loot")
    # No custom name: no CustomName key, as in Go.
    var plain = Tree()
    ShulkerBox().encode_nbt(plain, plain.root())
    assert_equal(plain.has(plain.root(), "CustomName"), False)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
