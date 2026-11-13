from ignis.block.cube.pos import Pos
from ignis.block.cube.range import Range
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_pos() raises:
    var p = Pos(1, 2, 3)
    assert_equal(p.add(Pos(1, 1, 1)), Pos(2, 3, 4))
    assert_equal(p.sub(Pos(1, 1, 1)), Pos(0, 1, 2))
    assert_equal(String(p), "(1, 2, 3)")
    assert_true(Pos(0, -65, 0).out_of_bounds(Range(-64, 319)))
    assert_false(Pos(0, 319, 0).out_of_bounds(Range(-64, 319)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
