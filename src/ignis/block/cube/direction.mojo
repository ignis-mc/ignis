"""Horizontal directions, ported from Dragonfly `server/block/cube/direction.go`.
"""

from .face import Face


struct Direction(Equatable, ImplicitlyCopyable, Intable, Writable):
    """A horizontal direction: north, south, west or east (Go `cube.Direction`,
    an `int`)."""

    var _v: UInt8

    comptime NORTH = Direction(0)
    """Go `cube.North`."""
    comptime SOUTH = Direction(1)
    """Go `cube.South`."""
    comptime WEST = Direction(2)
    """Go `cube.West`."""
    comptime EAST = Direction(3)
    """Go `cube.East`."""

    def __init__(out self, v: Int):
        """Creates a direction from its value (Go `cube.Direction(v)`).

        Args:
            v: 0 to 3.
        """
        self._v = UInt8(v)

    def __int__(self) -> Int:
        """Returns the value of the direction (Go `int(d)`).

        Returns:
            0 to 3.
        """
        return Int(self._v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two directions.

        Args:
            other: The direction to compare with.

        Returns:
            True if both are the same direction.
        """
        return self._v == other._v

    def face(self) -> Face:
        """Returns the face that corresponds with the direction.

        Returns:
            The horizontal face.
        """
        return Face(Int(self._v) + 2)

    def opposite(self) -> Direction:
        """Returns the opposite direction.

        Returns:
            The direction pointing the other way.
        """
        return Direction(Int(self._v ^ 1))

    def rotate_right(self) -> Direction:
        """Rotates the direction 90 degrees clockwise.

        Returns:
            The rotated direction.
        """
        if self == Direction.NORTH:
            return Direction.EAST
        if self == Direction.EAST:
            return Direction.SOUTH
        if self == Direction.SOUTH:
            return Direction.WEST
        return Direction.NORTH

    def rotate_left(self) -> Direction:
        """Rotates the direction 90 degrees counter-clockwise.

        Returns:
            The rotated direction.
        """
        if self == Direction.NORTH:
            return Direction.WEST
        if self == Direction.EAST:
            return Direction.NORTH
        if self == Direction.SOUTH:
            return Direction.EAST
        return Direction.SOUTH

    def write_to(self, mut writer: Some[Writer]):
        """Writes the direction as `north`, `south`, `west` or `east` (Go
        `String`).

        Args:
            writer: The destination.
        """
        if self == Direction.NORTH:
            writer.write("north")
        elif self == Direction.SOUTH:
            writer.write("south")
        elif self == Direction.WEST:
            writer.write("west")
        else:
            writer.write("east")


def directions() -> List[Direction]:
    """Returns the four directions in Go's order: north, east, south, west
    (Go `cube.Directions`).

    Returns:
        The directions.
    """
    return [Direction.NORTH, Direction.EAST, Direction.SOUTH, Direction.WEST]
