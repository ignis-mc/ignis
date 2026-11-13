from ignis.internal.mgl64 import Vec3, float_equal
from minecraft.protocol.math import Vec3 as ProtocolVec3
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_false,
    assert_true,
)


def test_arithmetic() raises:
    var v = Vec3(1, 2, 3) + Vec3(3, 2, 1) - Vec3(1, 1, 1)
    assert_true(v == Vec3(3, 3, 3))
    assert_almost_equal(Vec3(3, 4, 0).len(), 5)


def test_float_equal() raises:
    assert_true(float_equal(0, 1e-21))
    assert_false(float_equal(0, 1e-19))
    assert_true(float_equal(1e6, 1e6 + 1e-6))
    assert_false(float_equal(1, 1.001))
    assert_true(Vec3(1, 1, 1).approx_equal(Vec3(1, 1, 1 + 1e-12)))


def test_protocol_round_trip() raises:
    var v = Vec3.from_protocol(ProtocolVec3(1.5, -2.25, 3))
    assert_true(v == Vec3(1.5, -2.25, 3))
    assert_almost_equal(v.to_protocol().y, -2.25)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
