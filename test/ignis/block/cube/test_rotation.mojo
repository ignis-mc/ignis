from ignis.block.cube.rotation import Rotation
from std.testing import TestSuite, assert_equal


def test_add_wraps_like_go() raises:
    # Go `fix`: Mod(r+sign*180, 360) - sign*180, pitch the same over 180.
    assert_equal(Rotation(170, 10).add(Rotation(20, 0)), Rotation(-170, 10))
    assert_equal(Rotation(-170, 0).add(Rotation(-20, 0)), Rotation(170, 0))
    assert_equal(Rotation(0, 80).add(Rotation(0, 20)), Rotation(0, -80))
    assert_equal(Rotation(10, 5).add(Rotation(5, 5)), Rotation(15, 10))
    assert_equal(Rotation(1, 2).yaw(), 1.0)
    assert_equal(Rotation(1, 2).pitch(), 2.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
