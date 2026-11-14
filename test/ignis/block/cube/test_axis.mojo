from ignis.block.cube.axis import Axis, axes
from ignis.block.cube.face import Face
from std.testing import TestSuite, assert_equal, assert_true


def test_axes() raises:
    var all = axes()
    assert_equal(String(all[0]), "x")
    assert_equal(String(all[1]), "y")
    assert_equal(String(all[2]), "z")
    assert_equal(Int(Axis.Y), 0)
    assert_equal(Int(Axis.Z), 1)
    assert_equal(Int(Axis.X), 2)
    assert_true(Axis.X.rotate_left() == Axis.Z)
    assert_true(Axis.Y.rotate_right() == Axis.Y)
    var f = Axis.X.faces()
    assert_true(f[0] == Face.WEST and f[1] == Face.EAST)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
