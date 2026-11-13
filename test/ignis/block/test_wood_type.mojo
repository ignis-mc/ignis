from ignis.block.leaves_type import (
    LeavesType,
    leaves_types,
    poplar_leaves_types,
    wood_leaves_types,
)
from ignis.block.wood_type import WoodType, wood_types
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_wood_types() raises:
    var all = wood_types()
    assert_equal(len(all), 13)
    assert_equal(String(all[5]), "dark_oak")
    assert_equal(all[12].name(), "Poplar Wood")
    assert_false(WoodType.CRIMSON.flammable())
    assert_false(WoodType.WARPED.flammable())
    assert_true(WoodType.BAMBOO.flammable())


def test_leaves_round_trip() raises:
    # Go WoodType.Leaves and LeavesType.Wood are inverses where both exist.
    for w in wood_types():
        if case .Some(l) = w.leaves():
            assert_true(l.wood().value() == w)
    assert_false(Bool(WoodType.BAMBOO.leaves()))
    assert_false(Bool(WoodType.POPLAR.leaves()))
    assert_false(Bool(LeavesType.AZALEA.wood()))
    assert_true(LeavesType.RED_POPLAR.wood().value() == WoodType.POPLAR)
    assert_equal(len(leaves_types()), 14)
    assert_equal(len(wood_leaves_types()), 12)
    assert_equal(len(poplar_leaves_types()), 3)
    assert_equal(String(LeavesType.FLOWERING_AZALEA), "azalea_leaves_flowered")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
