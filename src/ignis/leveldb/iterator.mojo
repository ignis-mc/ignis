"""Iterators over tables, the memtable and the whole database, ported from
goleveldb `table/reader.go` (`indexIter`), `iterator/indexed_iter.go`,
`iterator/merged_iter.go` and `db_iter.go`.

Iterators own what they read: a memtable iterator holds a copy of the
memtable and a table iterator holds copies of the table indexes, so a
database iterator stays valid while the database keeps changing (like a
goleveldb iterator with its implicit snapshot), as long as the table files
it reads are not removed by a compaction in the meantime.
"""

from .key import (
    KEY_TYPE_DEL,
    compare_internal,
    internal_key,
    key_type,
    ukey,
    KEY_MAX_SEQ,
    KEY_TYPE_VAL,
)
from .memdb import MemDB
from .table import BlockIter, Table
from .util import compare_bytes


struct TableStream(Movable):
    """Iterates the entries of tables that do not overlap, in key order."""

    var _tables: List[Table]
    var _ti: Int
    var _bi: Int
    var _block: Optional[BlockIter]

    def __init__(out self, var tables: List[Table]):
        """Creates an unpositioned iterator.

        Args:
            tables: The tables, sorted by key range.
        """
        self._tables = tables^
        self._ti = 0
        self._bi = 0
        self._block = None

    def valid(self) -> Bool:
        """Reports whether the iterator is at an entry.

        Returns:
            True if positioned.
        """
        if self._block:
            return self._block.value().valid()
        return False

    def key(self) -> Span[UInt8, origin_of(self._block.value()._key)]:
        """Returns the current internal key.

        Returns:
            A view of the key.
        """
        return self._block.value().key()

    def value(self) -> Span[UInt8, origin_of(self._block.value()._data)]:
        """Returns the current value.

        Returns:
            A view of the value.
        """
        return self._block.value().value()

    def _settle(mut self) raises:
        # Moves forward to the next entry if the current block is used up.
        while True:
            if self._block and self._block.value().valid():
                return
            if self._block:
                self._bi += 1
                self._block = None
            if self._ti >= len(self._tables):
                return
            if self._bi >= self._tables[self._ti].blocks():
                self._ti += 1
                self._bi = 0
                continue
            var b = self._tables[self._ti].read_block(self._bi)
            b.first()
            self._block = b^

    def first(mut self) raises:
        """Moves to the first entry.

        Raises:
            If a block cannot be read or is corrupt.
        """
        self._ti = 0
        self._bi = 0
        self._block = None
        self._settle()

    def next(mut self) raises:
        """Moves to the next entry.

        Raises:
            If a block cannot be read or is corrupt.
        """
        if self._block:
            self._block.value().next()
        self._settle()

    def seek(mut self, ikey: Span[mut=False, UInt8, _]) raises:
        """Moves to the first entry not less than `ikey`.

        Args:
            ikey: The internal key.

        Raises:
            If a block cannot be read or is corrupt.
        """
        self._block = None
        var lo = 0
        var hi = len(self._tables)
        while lo < hi:
            var mid = (lo + hi) // 2
            if compare_internal(Span(self._tables[mid].imax), ikey) < 0:
                lo = mid + 1
            else:
                hi = mid
        self._ti = lo
        self._bi = 0
        if lo >= len(self._tables):
            return
        self._bi = self._tables[lo].find_block(ikey)
        if self._bi < self._tables[lo].blocks():
            var b = self._tables[lo].read_block(self._bi)
            b.seek(ikey)
            self._block = b^
        self._settle()


struct MemStream(Movable):
    """Iterates a snapshot of a memtable."""

    var _mem: MemDB
    var _node: Int

    def __init__(out self, var mem: MemDB):
        """Creates an unpositioned iterator.

        Args:
            mem: The memtable snapshot.
        """
        self._mem = mem^
        self._node = 0

    def valid(self) -> Bool:
        """Reports whether the iterator is at an entry.

        Returns:
            True if positioned.
        """
        return self._node != 0

    def key(self) -> Span[UInt8, origin_of(self._mem._kv)]:
        """Returns the current internal key.

        Returns:
            A view of the key.
        """
        return self._mem.key_at(self._node)

    def value(self) -> Span[UInt8, origin_of(self._mem._kv)]:
        """Returns the current value.

        Returns:
            A view of the value.
        """
        return self._mem.value_at(self._node)

    def first(mut self):
        """Moves to the first entry."""
        self._node = self._mem.first()

    def next(mut self):
        """Moves to the next entry."""
        if self._node != 0:
            self._node = self._mem.next(self._node)

    def seek(mut self, ikey: Span[mut=False, UInt8, _]):
        """Moves to the first entry not less than `ikey`.

        Args:
            ikey: The internal key.
        """
        self._node = self._mem.find_ge(ikey)


struct MergedStream(Movable):
    """Merges a memtable iterator and table iterators into one stream of
    internal keys in order (Go `mergedIterator`). For equal user keys the
    newest entry comes first."""

    var _mem: Optional[MemStream]
    var _tables: List[TableStream]
    var _cur: Int
    var key: List[UInt8]
    """The current internal key."""
    var value: List[UInt8]
    """The current value."""

    def __init__(
        out self, var mem: Optional[MemStream], var tables: List[TableStream]
    ):
        """Creates an unpositioned merged iterator.

        Args:
            mem: The memtable iterator, if any.
            tables: The table iterators.
        """
        self._mem = mem^
        self._tables = tables^
        self._cur = -2
        self.key = List[UInt8]()
        self.value = List[UInt8]()

    def valid(self) -> Bool:
        """Reports whether the iterator is at an entry.

        Returns:
            True if positioned.
        """
        return self._cur != -2

    def _pick(mut self):
        # Chooses the source with the smallest key and copies its entry.
        var best = -2
        if self._mem and self._mem.value().valid():
            best = -1
        for i in range(len(self._tables)):
            if not self._tables[i].valid():
                continue
            if best == -2:
                best = i
            elif best == -1:
                if (
                    compare_internal(
                        self._tables[i].key(), self._mem.value().key()
                    )
                    < 0
                ):
                    best = i
            elif (
                compare_internal(
                    self._tables[i].key(), self._tables[best].key()
                )
                < 0
            ):
                best = i
        self._cur = best
        if best == -1:
            self.key = List[UInt8](self._mem.value().key())
            self.value = List[UInt8](self._mem.value().value())
        elif best >= 0:
            self.key = List[UInt8](self._tables[best].key())
            self.value = List[UInt8](self._tables[best].value())

    def first(mut self) raises:
        """Moves to the first entry.

        Raises:
            If a block cannot be read or is corrupt.
        """
        if self._mem:
            self._mem.value().first()
        for i in range(len(self._tables)):
            self._tables[i].first()
        self._pick()

    def seek(mut self, ikey: Span[mut=False, UInt8, _]) raises:
        """Moves to the first entry not less than `ikey`.

        Args:
            ikey: The internal key.

        Raises:
            If a block cannot be read or is corrupt.
        """
        if self._mem:
            self._mem.value().seek(ikey)
        for i in range(len(self._tables)):
            self._tables[i].seek(ikey)
        self._pick()

    def next(mut self) raises:
        """Moves to the next entry.

        Raises:
            If a block cannot be read or is corrupt.
        """
        if self._cur == -1:
            self._mem.value().next()
        elif self._cur >= 0:
            self._tables[self._cur].next()
        else:
            return
        self._pick()


struct Iterator(Movable):
    """Iterates the live key/value pairs of a database in key order (Go
    `dbIter`): the newest version of each user key, skipping deleted keys.

    Like a goleveldb iterator, `next` must be called before the first
    entry is available; `seek` positions directly.
    """

    var _m: MergedStream
    var _started: Bool
    var _valid: Bool
    var _key: List[UInt8]
    var _value: List[UInt8]

    def __init__(out self, var m: MergedStream):
        """Wraps a merged stream.

        Args:
            m: The stream over the memtable and every table.
        """
        self._m = m^
        self._started = False
        self._valid = False
        self._key = List[UInt8]()
        self._value = List[UInt8]()

    def key(self) -> Span[UInt8, origin_of(self._key)]:
        """Returns the current user key.

        Returns:
            A view of the key.
        """
        return Span(self._key)

    def value(self) -> Span[UInt8, origin_of(self._value)]:
        """Returns the current value.

        Returns:
            A view of the value.
        """
        return Span(self._value)

    def valid(self) -> Bool:
        """Reports whether the iterator is at an entry.

        Returns:
            True if positioned.
        """
        return self._valid

    def _fill(mut self, var skip_ukey: Bool) raises -> Bool:
        # Finds the next live entry at or after the merged position. When
        # `skip_ukey` is set, entries with the current user key are older
        # versions and skipped.
        while self._m.valid():
            var uk = ukey(Span(self._m.key))
            if skip_ukey and compare_bytes(uk, Span(self._key)) == 0:
                self._m.next()
                continue
            self._key = List[UInt8](uk)
            if key_type(Span(self._m.key)) == KEY_TYPE_DEL:
                skip_ukey = True
                self._m.next()
                continue
            self._value = self._m.value.copy()
            self._valid = True
            return True
        self._valid = False
        self._key.clear()
        self._value.clear()
        return False

    def first(mut self) raises -> Bool:
        """Moves to the first live entry (Go `First`).

        Returns:
            True if there is one.

        Raises:
            If a block cannot be read or is corrupt.
        """
        self._started = True
        self._m.first()
        return self._fill(False)

    def seek(mut self, key: Span[mut=False, UInt8, _]) raises -> Bool:
        """Moves to the first live entry with a key not less than `key` (Go
        `Seek`).

        Args:
            key: The user key.

        Returns:
            True if there is one.

        Raises:
            If a block cannot be read or is corrupt.
        """
        self._started = True
        self._m.seek(Span(internal_key(key, KEY_MAX_SEQ, KEY_TYPE_VAL)))
        return self._fill(False)

    def next(mut self) raises -> Bool:
        """Moves to the next live entry; the first call moves to the first
        (Go `Next`).

        Returns:
            True if there is one.

        Raises:
            If a block cannot be read or is corrupt.
        """
        if not self._started:
            return self.first()
        if not self._valid:
            return False
        self._m.next()
        return self._fill(True)
