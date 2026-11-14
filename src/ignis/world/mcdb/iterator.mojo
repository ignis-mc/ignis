"""Iterating every stored column, ported from Dragonfly
`server/world/mcdb/iterator.go`."""

from std.collections import Dict

from ...leveldb.iterator import Iterator
from ..chunk.column import Column
from ..dimension import Dimension, OVERWORLD, dimension_by_id
from ..position import ChunkPos
from .db import DB
from .keys import KEY_VERSION, KEY_VERSION_OLD


@fieldwise_init
struct IteratorRange(Copyable, Defaultable):
    """Limits the columns a `ColumnIterator` yields (Go `IteratorRange`)."""

    var min: ChunkPos
    """The smallest position, inclusive."""
    var max: ChunkPos
    """The largest position, exclusive. With `min`, all zero means no
    limit."""
    var dimension: Optional[Dimension]
    """The only dimension to read, or None for every dimension."""

    def __init__(out self):
        """Creates a range that admits every column."""
        self.min = ChunkPos(0, 0)
        self.max = ChunkPos(0, 0)
        self.dimension = None

    def within(self, pos: ChunkPos, dim: Dimension) -> Bool:
        """Reports whether a column is in the range (Go `within`)."""
        if self.dimension and self.dimension.value() != dim:
            return False
        var zero = ChunkPos(0, 0)
        return (self.min == zero and self.max == zero) or (
            pos.x() >= self.min.x()
            and pos.x() < self.max.x()
            and pos.z() >= self.min.z()
            and pos.z() < self.max.z()
        )


struct ColumnIterator(Movable):
    """Iterates a world's columns in key order (Go `ColumnIterator`).

    The database is passed to `next`, which loads each column; Go keeps a
    pointer to it instead.
    """

    var _it: Iterator
    var _r: IteratorRange
    var _seen: Dict[String, Bool]
    var _current: Optional[Column]
    var _pos: ChunkPos
    var _dim: Dimension

    def __init__(out self, db: DB, var r: IteratorRange):
        """Creates an iterator (Go `DB.NewColumnIterator`)."""
        self._it = db.ldb().new_iterator()
        self._r = r^
        self._seen = Dict[String, Bool]()
        self._current = None
        self._pos = ChunkPos(0, 0)
        self._dim = OVERWORLD

    def next(mut self, db: DB) raises -> Bool:
        """Moves to the next column (Go `Next`)."""
        while self._it.next():
            var k = self._it.key()
            var n = len(k)
            if (n != 9 and n != 13) or (
                k[n - 1] != KEY_VERSION and k[n - 1] != KEY_VERSION_OLD
            ):
                continue
            var dim = OVERWORLD
            if n > 9:
                var id = Int(
                    UInt32(k[8])
                    | (UInt32(k[9]) << 8)
                    | (UInt32(k[10]) << 16)
                    | (UInt32(k[11]) << 24)
                )
                var d = dimension_by_id(id)
                if not d:
                    raise Error(t"unknown dimension id {id}")
                dim = d.value()
            var x = Int32(
                UInt32(k[0])
                | (UInt32(k[1]) << 8)
                | (UInt32(k[2]) << 16)
                | (UInt32(k[3]) << 24)
            )
            var z = Int32(
                UInt32(k[4])
                | (UInt32(k[5]) << 8)
                | (UInt32(k[6]) << 16)
                | (UInt32(k[7]) << 24)
            )
            var pos = ChunkPos(x, z)
            if not self._r.within(pos, dim):
                continue
            var key = String(dim.id, ":", x, ":", z)
            if key in self._seen:
                # Already yielded: the chunk has both version keys.
                continue
            var col = db.read_column(pos, dim)
            if not col:
                continue
            self._seen[key] = True
            self._current = col^
            self._pos = pos
            self._dim = dim
            return True
        self._current = None
        return False

    def column(ref self) -> ref[self._current] Optional[Column]:
        """Returns the current column (Go `Column`)."""
        return self._current

    def position(self) -> ChunkPos:
        """Returns the position of the current column (Go `Position`)."""
        return self._pos

    def dimension(self) -> Dimension:
        """Returns the dimension of the current column (Go `Dimension`)."""
        return self._dim
