from ignis.internal.color import RGBA
from ignis.item.armour import ArmourTier, int32_from_rgba, rgba_from_int32
from ignis.item.armour_trim import ArmourTrim
from ignis.item.boots import Boots
from ignis.item.chestplate import Chestplate
from ignis.item.diamond import Diamond
from ignis.item.helmet import Helmet
from ignis.item.leggings import Leggings
from ignis.item.smithing_template_type import SmithingTemplateType
from ignis.world.item import AnyItem
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_hash_round_trip() raises:
    for h in Helmet.all_items():
        assert_true(Helmet.from_hash(h.hash()) == h)
    for c in Chestplate.all_items():
        assert_true(Chestplate.from_hash(c.hash()) == c)
    for l in Leggings.all_items():
        assert_true(Leggings.from_hash(l.hash()) == l)
    for b in Boots.all_items():
        assert_true(Boots.from_hash(b.hash()) == b)
    assert_equal(len(Helmet.all_items()), 7)


def test_names_and_durability() raises:
    assert_equal(
        Helmet(tier=ArmourTier.CHAIN).encode_item().name,
        "minecraft:chainmail_helmet",
    )
    assert_equal(
        Boots(tier=ArmourTier.NETHERITE).encode_item().name,
        "minecraft:netherite_boots",
    )
    # Go: int(363 + 363/2.2) = 528.
    assert_equal(
        Chestplate(tier=ArmourTier.DIAMOND).durability_info().max_durability,
        528,
    )


def test_colour_int32() raises:
    assert_equal(int32_from_rgba(RGBA()), Int32(-0x1000000))
    var c = RGBA(0x12, 0x34, 0x56, 0xFF)
    assert_equal(rgba_from_int32(int32_from_rgba(c)), c)


def test_nbt() raises:
    var tier = ArmourTier.LEATHER
    tier.colour = RGBA(0x12, 0x34, 0x56, 0xFF)
    var h = Helmet(
        tier=tier,
        trim=ArmourTrim(SmithingTemplateType.WILD, AnyItem.of(Diamond())),
    )
    var tag = Tree()
    h.encode_nbt(tag, tag.root())
    assert_equal(tag.get_int(tag.root(), "customColor"), Int32(-15584170))
    var back = Helmet().decode_nbt(tag, tag.root())
    assert_true(back == h)
    assert_false(back == Helmet())
    var plain = Tree()
    Helmet(tier=ArmourTier.IRON).encode_nbt(plain, plain.root())
    assert_equal(plain.length(plain.root()), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
