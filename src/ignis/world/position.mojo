"""Chunk and sub-chunk positions, ported from Dragonfly
`server/world/position.go`.

Only the types the world needs are ported so far.
"""

from std.math import floor

from ..block.cube.pos import Pos
from ..mgl64 import Vec3


@fieldwise_init
struct ChunkPos(Equatable, Hashable, ImplicitlyCopyable, Writable):
    """The position of a chunk column, in chunks (Go `[2]int32`)."""

    var _x: Int32
    var _z: Int32

    def x(self) -> Int32:
        """Returns the X coordinate."""
        return self._x

    def z(self) -> Int32:
        """Returns the Z coordinate."""
        return self._z

    def write_to(self, mut writer: Some[Writer]):
        """Writes the position as `(x, z)`."""
        writer.write("(", self._x, ", ", self._z, ")")


@fieldwise_init
struct SubChunkPos(Equatable, Hashable, ImplicitlyCopyable, Writable):
    """The position of a sub-chunk, in sub-chunks (Go `[3]int32`)."""

    var _x: Int32
    var _y: Int32
    var _z: Int32

    def x(self) -> Int32:
        """Returns the X coordinate."""
        return self._x

    def y(self) -> Int32:
        """Returns the Y coordinate."""
        return self._y

    def z(self) -> Int32:
        """Returns the Z coordinate."""
        return self._z

    def write_to(self, mut writer: Some[Writer]):
        """Writes the position as `(x, y, z)`."""
        writer.write("(", self._x, ", ", self._y, ", ", self._z, ")")


def chunk_pos_from_vec3(v: Vec3) -> ChunkPos:
    """Returns the chunk a vector is in (Go `chunkPosFromVec3`)."""
    return ChunkPos(
        Int32(Int(floor(v.x()))) >> 4, Int32(Int(floor(v.z()))) >> 4
    )


def chunk_pos_from_block_pos(p: Pos) -> ChunkPos:
    """Returns the chunk a block is in (Go `chunkPosFromBlockPos`)."""
    return ChunkPos(Int32(p.x() >> 4), Int32(p.z() >> 4))
