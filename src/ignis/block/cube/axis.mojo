"""Axes, ported from the block parts of Dragonfly
`server/block/cube/axis.go` (`Vec3` follows with the maths package).
"""

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
        """Creates an axis from its value (Go `cube.Axis(v)`).

        Args:
            v: 0 to 2.
        """
        self._v = UInt8(v)

    def __int__(self) -> Int:
        """Returns the value of the axis (Go `int(a)`).

        Returns:
            0 to 2.
        """
        return Int(self._v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two axes.

        Args:
            other: The axis to compare with.

        Returns:
            True if both are the same axis.
        """
        return self._v == other._v

    def rotate_left(self) -> Axis:
        """Rotates the axis 90 degrees horizontally.

        Returns:
            Z for X, X for Z and Y for Y.
        """
        if self == Axis.X:
            return Axis.Z
        if self == Axis.Z:
            return Axis.X
        return Axis.Y

    def rotate_right(self) -> Axis:
        """Rotates the axis 90 degrees horizontally.

        Returns:
            Z for X, X for Z and Y for Y.
        """
        return self.rotate_left()

    def faces(self) -> Tuple[Face, Face]:
        """Returns the faces on the negative and positive side of the axis.

        Returns:
            The negative and the positive face.
        """
        if self == Axis.X:
            return (Face.WEST, Face.EAST)
        if self == Axis.Y:
            return (Face.DOWN, Face.UP)
        return (Face.NORTH, Face.SOUTH)

    def write_to(self, mut writer: Some[Writer]):
        """Writes the axis as `x`, `y` or `z` (Go `String`).

        Args:
            writer: The destination.
        """
        if self == Axis.X:
            writer.write("x")
        elif self == Axis.Y:
            writer.write("y")
        else:
            writer.write("z")


def axes() -> List[Axis]:
    """Returns the axes X, Y and Z (Go `cube.Axes`).

    Returns:
        The axes.
    """
    return [Axis.X, Axis.Y, Axis.Z]
