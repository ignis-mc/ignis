from ignis.block.block import horizontal_direction
from ignis.block.cube.direction import Direction
from ignis.block.double_flower_type import (
    DoubleFlowerType,
    double_flower_types,
)
from ignis.block.leaves_type import LeavesType, leaves_types
from ignis.block.sapling_type import SaplingType, sapling_types
from ignis.block.wood_type import WoodType
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_sapling_type() raises:
    assert_equal(len(sapling_types()), 9)
    assert_true(SaplingType.DARK_OAK.wood() == WoodType.DARK_OAK)
    assert_true(SaplingType.POPLAR.wood() == WoodType.POPLAR)
    assert_true(SaplingType.POPLAR.leaves() == LeavesType.ORANGE_POPLAR)
    assert_equal(String(SaplingType.PALE_OAK), "pale_oak_sapling")
    # Leaves drop the sapling that grows into them.
    for t in leaves_types():
        if case .Some(s) = t.sapling():
            assert_true(s.wood() == t.wood().value())
    assert_false(Bool(LeavesType.MANGROVE.sapling()))
    assert_false(Bool(LeavesType.AZALEA.sapling()))


def test_double_flower_type_values() raises:
    var all = double_flower_types()
    assert_equal(len(all), 4)
    assert_equal(Int(DoubleFlowerType.ROSE_BUSH.uint8()), 4)
    assert_equal(String(DoubleFlowerType.PEONY), "peony")
    assert_equal(DoubleFlowerType.ROSE_BUSH.name(), "Rose Bush")


def test_horizontal_direction() raises:
    assert_true(horizontal_direction(Direction.SOUTH) == Direction.NORTH)
    assert_true(horizontal_direction(Direction.WEST) == Direction.SOUTH)
    assert_true(horizontal_direction(Direction.NORTH) == Direction.WEST)
    assert_true(horizontal_direction(Direction.EAST) == Direction.EAST)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
