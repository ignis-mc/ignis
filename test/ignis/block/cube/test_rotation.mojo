from ignis.block.cube.rotation import Rotation
from std.testing import TestSuite, assert_almost_equal


def test_add_wraps() raises:
    var r = Rotation(170, 80).add(Rotation(20, 20))
    assert_almost_equal(r.yaw(), -170)
    assert_almost_equal(r.pitch(), -80)
    var n = Rotation(-170, 0).add(Rotation(-20, 0))
    assert_almost_equal(n.yaw(), 170)


def test_add_in_range() raises:
    var r = Rotation(10, 5).add(Rotation(35, -15))
    assert_almost_equal(r.yaw(), 45)
    assert_almost_equal(r.pitch(), -10)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
