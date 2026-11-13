"""Chunk and sub-chunk positions, ported from Dragonfly
`server/world/position.go`.

Only the types the world core needs are ported so far.
"""


@fieldwise_init
struct ChunkPos(Equatable, ImplicitlyCopyable, Writable):
    """The position of a chunk column, in chunks (Go `[2]int32`)."""

    var _x: Int32
    var _z: Int32

    def x(self) -> Int32:
        """Returns the X coordinate.

        Returns:
            The X coordinate in chunks.
        """
        return self._x

    def z(self) -> Int32:
        """Returns the Z coordinate.

        Returns:
            The Z coordinate in chunks.
        """
        return self._z

    def write_to(self, mut writer: Some[Writer]):
        """Writes the position as `(x, z)`.

        Args:
            writer: The destination.
        """
        writer.write("(", self._x, ", ", self._z, ")")


@fieldwise_init
struct SubChunkPos(Equatable, ImplicitlyCopyable, Writable):
    """The position of a sub-chunk, in sub-chunks (Go `[3]int32`)."""

    var _x: Int32
    var _y: Int32
    var _z: Int32

    def x(self) -> Int32:
        """Returns the X coordinate.

        Returns:
            The X coordinate in sub-chunks.
        """
        return self._x

    def y(self) -> Int32:
        """Returns the Y coordinate.

        Returns:
            The Y coordinate in sub-chunks.
        """
        return self._y

    def z(self) -> Int32:
        """Returns the Z coordinate.

        Returns:
            The Z coordinate in sub-chunks.
        """
        return self._z

    def write_to(self, mut writer: Some[Writer]):
        """Writes the position as `(x, y, z)`.

        Args:
            writer: The destination.
        """
        writer.write("(", self._x, ", ", self._y, ", ", self._z, ")")
