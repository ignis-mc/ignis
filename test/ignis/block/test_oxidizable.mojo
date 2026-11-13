from ignis.block.copper import Copper
from ignis.block.copper_type import CopperType
from ignis.block.oxidation_type import OxidationType
from ignis.block.oxidizable import copper_block_name
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_copper_block_name() raises:
    assert_equal(
        copper_block_name("copper_grate", OxidationType.UNOXIDISED, False),
        "minecraft:copper_grate",
    )
    assert_equal(
        copper_block_name("copper_door", OxidationType.WEATHERED, True),
        "minecraft:waxed_weathered_copper_door",
    )


def test_oxidation_steps() raises:
    assert_false(Bool(OxidationType.UNOXIDISED.decrease()))
    assert_false(Bool(OxidationType.OXIDISED.increase()))
    assert_true(
        OxidationType.EXPOSED.increase().value() == OxidationType.WEATHERED
    )
    assert_true(
        OxidationType.EXPOSED.decrease().value() == OxidationType.UNOXIDISED
    )


def test_oxidisable() raises:
    var c = Copper(type=CopperType.CUT)
    assert_true(c.can_oxidate())
    assert_false(Copper(waxed=True).can_oxidate())
    var o = c.with_oxidation_level(OxidationType.OXIDISED)
    assert_true(o.oxidation_level() == OxidationType.OXIDISED)
    assert_equal(o.encode_block().name, "minecraft:oxidized_cut_copper")
    assert_equal(Copper().encode_block().name, "minecraft:copper_block")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
