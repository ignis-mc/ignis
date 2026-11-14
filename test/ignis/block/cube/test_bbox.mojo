from ignis.block.cube.bbox import BBox
from ignis.mgl64 import Vec3
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_box() raises:
    var b = BBox.box(1, 1, 1, 0, 0, 0)
    assert_equal(b.min(), Vec3(0, 0, 0))
    assert_equal(b.max(), Vec3(1, 1, 1))
    assert_true(b.vec3_within(Vec3(0.5, 0.5, 0.5)))
    # The faces are outside (Go `Vec3Within` is strict).
    assert_false(b.vec3_within(Vec3(0, 0.5, 0.5)))
    assert_equal(b.grow(1).min(), Vec3(-1, -1, -1))
    assert_equal(b.translate(Vec3(1, 0, 0)).max(), Vec3(2, 1, 1))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
