"""Block positions, ported from Dragonfly `server/block/cube/pos.go`.

Only the parts the world needs are ported so far.
"""

from std.math import floor

from ...mgl64 import Vec3
from .range import Range


@fieldwise_init
struct Pos(Equatable, Hashable, ImplicitlyCopyable, Writable):
    """The position of a block (Go `cube.Pos`, `[3]int`)."""

    var _x: Int
    var _y: Int
    var _z: Int

    def x(self) -> Int:
        """Returns the X coordinate.

        Returns:
            The X coordinate.
        """
        return self._x

    def y(self) -> Int:
        """Returns the Y coordinate.

        Returns:
            The Y coordinate.
        """
        return self._y

    def z(self) -> Int:
        """Returns the Z coordinate.

        Returns:
            The Z coordinate.
        """
        return self._z

    def out_of_bounds(self, r: Range) -> Bool:
        """Checks if the Y value is outside the range passed.

        Args:
            r: The range of the dimension.

        Returns:
            True if the position cannot hold a block.
        """
        return self._y > r.max() or self._y < r.min()

    def add(self, pos: Pos) -> Pos:
        """Adds two positions.

        Args:
            pos: The position to add.

        Returns:
            The sum.
        """
        return Pos(self._x + pos._x, self._y + pos._y, self._z + pos._z)

    def sub(self, pos: Pos) -> Pos:
        """Subtracts a position.

        Args:
            pos: The position to subtract.

        Returns:
            The difference.
        """
        return Pos(self._x - pos._x, self._y - pos._y, self._z - pos._z)

    def vec3(self) -> Vec3:
        """Returns the position as a vector (Go `Vec3`).

        Returns:
            The coordinates as floats.
        """
        return Vec3(Float64(self._x), Float64(self._y), Float64(self._z))

    def vec3_middle(self) -> Vec3:
        """Returns the position with 0.5 added on both horizontal axes (Go
        `Vec3Middle`).

        Returns:
            The vector.
        """
        return Vec3(
            Float64(self._x) + 0.5, Float64(self._y), Float64(self._z) + 0.5
        )

    def vec3_centre(self) -> Vec3:
        """Returns the position with 0.5 added on all axes (Go
        `Vec3Centre`).

        Returns:
            The vector.
        """
        return Vec3(
            Float64(self._x) + 0.5,
            Float64(self._y) + 0.5,
            Float64(self._z) + 0.5,
        )

    def neighbours(self, r: Range) -> List[Pos]:
        """Returns the positions directly around this one that are within
        the range (Go `Neighbours`, which calls a function for each).

        Args:
            r: The range of the dimension.

        Returns:
            The neighbours in Go's order (+x, -x, +y, -y, +z, -z); none if
            this position is out of bounds.
        """
        var out = List[Pos](capacity=6)
        if self.out_of_bounds(r):
            return out^
        out.append(Pos(self._x + 1, self._y, self._z))
        out.append(Pos(self._x - 1, self._y, self._z))
        if self._y + 1 <= r.max():
            out.append(Pos(self._x, self._y + 1, self._z))
        if self._y - 1 >= r.min():
            out.append(Pos(self._x, self._y - 1, self._z))
        out.append(Pos(self._x, self._y, self._z + 1))
        out.append(Pos(self._x, self._y, self._z - 1))
        return out^

    def write_to(self, mut writer: Some[Writer]):
        """Writes the position as `(x, y, z)`, as Go's `String` does.

        Args:
            writer: The destination.
        """
        writer.write("(", self._x, ", ", self._y, ", ", self._z, ")")


def pos_from_vec3(v: Vec3) -> Pos:
    """Returns the block position a vector is in (Go `PosFromVec3`).

    Args:
        v: The vector.

    Returns:
        The position, each coordinate floored.
    """
    return Pos(Int(floor(v.x())), Int(floor(v.y())), Int(floor(v.z())))
