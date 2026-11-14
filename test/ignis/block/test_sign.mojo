from ignis.block.sign import Sign
from ignis.block.wood_type import WoodType
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_true


def test_sign_item() raises:
    assert_equal(
        Sign(wood=WoodType.DARK_OAK).encode_item().name,
        "minecraft:dark_oak_sign",
    )
    assert_equal(Sign().max_count(), 16)
    assert_equal(Sign().fuel_info().duration, 10000)
    assert_equal(Sign(wood=WoodType.CRIMSON).fuel_info().duration, 0)


def test_sign_nbt() raises:
    var tag = Tree()
    var r = tag.root()
    Sign(waxed=True).encode_nbt(tag, r)
    assert_equal(tag.get_string(r, "id"), "Sign")
    assert_equal(tag.get_byte(r, "IsWaxed"), 1)
    var front = tag.get_compound(r, "FrontText")
    # Go's nbtconv.Int32FromRGBA writes the zero colour as opaque black.
    assert_equal(tag.get_int(front, "SignTextColor"), -0x1000000)
    assert_equal(tag.get_string(front, "Text"), "")
    assert_true(tag.has(r, "BackText"))
    assert_true(Sign().decode_nbt(tag, r).waxed)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
