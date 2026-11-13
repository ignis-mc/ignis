from ignis.block.cube.direction import Direction, directions
from ignis.block.cube.face import Face
from std.testing import TestSuite, assert_equal, assert_true


def test_values_and_names() raises:
    assert_equal(Int(Direction.NORTH), 0)
    assert_equal(Int(Direction.SOUTH), 1)
    assert_equal(Int(Direction.WEST), 2)
    assert_equal(Int(Direction.EAST), 3)
    var names = ["north", "east", "south", "west"]
    var all = directions()
    for i in range(4):
        assert_equal(String(all[i]), names[i])


def test_rotation() raises:
    for d in directions():
        assert_true(d.opposite().opposite() == d)
        assert_true(d.rotate_right().rotate_left() == d)
        assert_true(d.rotate_right().rotate_right() == d.opposite())
        assert_true(d.face().direction() == d)
    assert_true(Direction.NORTH.rotate_right() == Direction.EAST)
    assert_true(Direction.WEST.opposite() == Direction.EAST)
    assert_true(Direction.EAST.face() == Face.EAST)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
