from ignis.block.hash import HASH_REDSTONE_WIRE
from ignis.item.amethyst_shard import AmethystShard
from ignis.item.armour_trim import (
    ArmourTrim,
    armour_trim_materials,
    read_trim,
    trim_material_colour,
    trim_material_from_string,
    trim_material_name,
    write_trim,
)
from ignis.item.diamond import Diamond
from ignis.item.smithing_template_type import SmithingTemplateType
from ignis.world.item import AnyItem
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_materials() raises:
    var all = armour_trim_materials()
    assert_equal(len(all), 11)
    assert_equal(all[0], AnyItem.of(AmethystShard()))
    assert_equal(trim_material_name(all[0]), "amethyst")
    assert_equal(trim_material_colour(AnyItem.of(Diamond())), "§s")
    assert_equal(Diamond().trim_material(), "diamond")
    assert_equal(all[10].kind, HASH_REDSTONE_WIRE)
    assert_true(all[10].block)
    for m in all:
        assert_equal(
            trim_material_from_string(trim_material_name(m)).value(), m
        )
    assert_false(trim_material_from_string("wood"))


def test_zero() raises:
    assert_true(ArmourTrim().zero())
    var t = ArmourTrim(
        SmithingTemplateType.NETHERITE_UPGRADE, AnyItem.of(Diamond())
    )
    assert_true(t.zero())
    t.template = SmithingTemplateType.VEX
    assert_false(t.zero())


def test_nbt_round_trip() raises:
    var t = ArmourTrim(SmithingTemplateType.VEX, AnyItem.of(Diamond()))
    var tag = Tree()
    write_trim(tag, tag.root(), t)
    var trim = tag.get_compound(tag.root(), "Trim")
    assert_equal(tag.get_string(trim, "Material"), "diamond")
    assert_equal(tag.get_string(trim, "Pattern"), "vex")
    assert_true(read_trim(tag, tag.root()) == t)
    var empty = Tree()
    write_trim(empty, empty.root(), ArmourTrim())
    assert_false(empty.has(empty.root(), "Trim"))
    assert_true(read_trim(empty, empty.root()) == ArmourTrim())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
