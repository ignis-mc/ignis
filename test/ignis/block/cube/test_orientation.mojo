from ignis.block.cube.orientation import Orientation, orientation_from_yaw
from std.testing import TestSuite, assert_equal, assert_true


def test_from_yaw() raises:
    assert_equal(Int(orientation_from_yaw(0)), 0)
    assert_equal(Int(orientation_from_yaw(22.5)), 1)
    assert_equal(Int(orientation_from_yaw(11.25)), 1)  # half rounds up
    assert_equal(Int(orientation_from_yaw(370)), 0)
    # Go math.Mod keeps the sign and math.Round rounds away from zero.
    assert_equal(Int(orientation_from_yaw(-90)), -4)
    assert_equal(Int(orientation_from_yaw(-11.25)), -1)


def test_rotation() raises:
    assert_equal(Orientation(4).yaw(), 90.0)
    assert_equal(Int(Orientation(0).opposite()), 8)
    assert_equal(Int(Orientation(4).rotate_left()), 0)
    assert_equal(Int(Orientation(4).rotate_right()), 8)
    assert_true(Orientation(3) == Orientation(3))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
