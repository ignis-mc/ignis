"""Block positions, ported from Dragonfly `server/block/cube/pos.go`.

Only the parts the world core needs are ported so far.
"""

from .range import Range


@fieldwise_init
struct Pos(Equatable, ImplicitlyCopyable, Writable):
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

    def write_to(self, mut writer: Some[Writer]):
        """Writes the position as `(x, y, z)`, as Go's `String` does.

        Args:
            writer: The destination.
        """
        writer.write("(", self._x, ", ", self._y, ", ", self._z, ")")
