from ignis.block.attachment import standing_attachment
from ignis.block.cube.orientation import Orientation
from ignis.block.skull import Skull
from ignis.block.skull_type import SkullType
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_true


def test_skull_item() raises:
    assert_equal(
        Skull(type=SkullType.CREEPER).encode_item().name,
        "minecraft:creeper_head",
    )
    assert_equal(len(Skull.all_items()), 7)
    assert_true(Skull().helmet())


def test_skull_nbt_round_trip() raises:
    var tag = Tree()
    var r = tag.root()
    var s = Skull(attach=standing_attachment(Orientation(4)))
    s.encode_nbt(tag, r)
    assert_equal(tag.get_string(r, "id"), "Skull")
    assert_equal(tag.get_byte(r, "SkullType"), 255)
    assert_equal(tag.get_float(r, "Rotation"), 90)
    var back = Skull().decode_nbt(tag, r)
    assert_equal(Int(back.attach.orientation()), 4)
    # SkullType 255 keeps the type the skull already has.
    assert_true(back.type == Skull().type)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
