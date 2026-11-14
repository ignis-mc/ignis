"""Axes, ported from Dragonfly `server/block/cube/axis.go`."""

from ...mgl64 import Vec3
from .face import Face


struct Axis(Equatable, ImplicitlyCopyable, Intable, Writable):
    """An axis a block may be aligned with (Go `cube.Axis`, an `int`)."""

    var _v: UInt8

    comptime Y = Axis(0)
    """Go `cube.Y`."""
    comptime Z = Axis(1)
    """Go `cube.Z`."""
    comptime X = Axis(2)
    """Go `cube.X`."""

    def __init__(out self, v: Int):
        """Creates an axis from its value (Go `cube.Axis(v)`)."""
        self._v = UInt8(v)

    def __int__(self) -> Int:
        """Returns the value of the axis (Go `int(a)`)."""
        return Int(self._v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two axes."""
        return self._v == other._v

    def rotate_left(self) -> Axis:
        """Rotates the axis 90 degrees horizontally."""
        if self == Axis.X:
            return Axis.Z
        if self == Axis.Z:
            return Axis.X
        return Axis.Y

    def rotate_right(self) -> Axis:
        """Rotates the axis 90 degrees horizontally."""
        return self.rotate_left()

    def faces(self) -> Tuple[Face, Face]:
        """Returns the faces on the negative and positive side of the axis."""
        if self == Axis.X:
            return (Face.WEST, Face.EAST)
        if self == Axis.Y:
            return (Face.DOWN, Face.UP)
        return (Face.NORTH, Face.SOUTH)

    def vec3(self) -> Vec3:
        """Returns the unit vector along the axis (Go `Vec3`)."""
        if self == Axis.X:
            return Vec3(1, 0, 0)
        if self == Axis.Y:
            return Vec3(0, 1, 0)
        return Vec3(0, 0, 1)

    def write_to(self, mut writer: Some[Writer]):
        """Writes the axis as `x`, `y` or `z` (Go `String`)."""
        if self == Axis.X:
            writer.write("x")
        elif self == Axis.Y:
            writer.write("y")
        else:
            writer.write("z")


def axes() -> List[Axis]:
    """Returns the axes X, Y and Z (Go `cube.Axes`)."""
    return [Axis.X, Axis.Y, Axis.Z]
