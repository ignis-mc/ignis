from ignis.mgl64 import Vec3
from std.testing import TestSuite, assert_equal


def test_vec3() raises:
    var v = Vec3(1, 2, 3)
    assert_equal(v.add(Vec3(1, 1, 1)), Vec3(2, 3, 4))
    assert_equal(v.sub(Vec3(1, 1, 1)), Vec3(0, 1, 2))
    assert_equal(v.mul(2), Vec3(2, 4, 6))
    assert_equal(Vec3(3, 4, 0).len(), 5.0)
    assert_equal(String(Vec3()), "[0.0 0.0 0.0]")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
