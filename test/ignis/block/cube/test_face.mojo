from ignis.block.cube.axis import Axis
from ignis.block.cube.face import Face, faces, horizontal_faces
from std.testing import TestSuite, assert_equal, assert_true


def test_values_and_names() raises:
    var names = ["down", "up", "north", "east", "south", "west"]
    var all = faces()
    for i in range(6):
        assert_equal(String(all[i]), names[i])
    assert_equal(Int(Face.EAST), 5)
    assert_equal(len(horizontal_faces()), 4)


def test_relations() raises:
    for f in faces():
        assert_true(f.opposite().opposite() == f)
        assert_true(f.opposite().axis() == f.axis())
    assert_true(Face.DOWN.opposite() == Face.UP)
    assert_true(Face.NORTH.opposite() == Face.SOUTH)
    assert_true(Face.WEST.axis() == Axis.X)
    assert_true(Face.SOUTH.axis() == Axis.Z)
    assert_true(Face.UP.axis() == Axis.Y)
    assert_true(Face.UP.rotate_right() == Face.UP)
    assert_true(Face.NORTH.rotate_left() == Face.WEST)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
