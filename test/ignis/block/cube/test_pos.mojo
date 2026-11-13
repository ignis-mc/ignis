from ignis.block.cube.pos import Pos, pos_from_vec3
from ignis.mgl64 import Vec3
from ignis.block.cube.range import Range
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_pos() raises:
    var p = Pos(1, 2, 3)
    assert_equal(p.add(Pos(1, 1, 1)), Pos(2, 3, 4))
    assert_equal(p.sub(Pos(1, 1, 1)), Pos(0, 1, 2))
    assert_equal(String(p), "(1, 2, 3)")
    assert_true(Pos(0, -65, 0).out_of_bounds(Range(-64, 319)))
    assert_false(Pos(0, 319, 0).out_of_bounds(Range(-64, 319)))


def test_neighbours() raises:
    var r = Range(-64, 319)
    var n = Pos(1, 2, 3).neighbours(r)
    assert_equal(len(n), 6)
    assert_equal(n[0], Pos(2, 2, 3))
    assert_equal(n[2], Pos(1, 3, 3))
    assert_equal(n[5], Pos(1, 2, 2))
    # Neighbours outside the range are left out.
    assert_equal(len(Pos(0, 319, 0).neighbours(r)), 5)
    assert_equal(len(Pos(0, 400, 0).neighbours(r)), 0)


def test_vec3() raises:
    assert_equal(Pos(1, 2, 3).vec3(), Vec3(1, 2, 3))
    assert_equal(Pos(1, 2, 3).vec3_centre(), Vec3(1.5, 2.5, 3.5))
    assert_equal(Pos(1, 2, 3).vec3_middle(), Vec3(1.5, 2, 3.5))
    assert_equal(pos_from_vec3(Vec3(-0.5, 2.9, 3)), Pos(-1, 2, 3))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
