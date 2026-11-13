"""Sorted string tables (`.ldb`/`.sst`), ported from goleveldb `table/`
(`table.go`, `writer.go`, `reader.go`).

A table is a sequence of blocks, then a 48-byte footer: the metaindex and
index block handles (varint offset and length), zero padding, and the magic
`0xdb4775248b80fb57` little-endian. Every block is followed by a 5-byte
trailer: the compression type and the masked CRC-32C of block and type.
Blocks hold prefix-compressed entries (shared length, unshared length and
value length as varints, then the unshared key bytes and the value),
restart offsets every `restart_interval` entries, and the restart count.

The index block maps a separator key at or after the last key of each data
block to that block's handle; the metaindex maps `filter.<name>` to the
filter block. Keys in data and index blocks are internal keys.
"""

from ..internal.fs import File, open_read
from .compress import NO_COMPRESSION, compress, decompress
from .filter import (
    FILTER_NAME,
    GO_FILTER_NAME,
    FilterBlockReader,
    FilterBlockWriter,
)
from .key import compare_internal, separator, successor, ukey
from .util import (
    compare_bytes,
    get_u32,
    masked_crc,
    put_u32,
    put_uvarint,
    read_varint_int,
)

comptime BLOCK_TRAILER_LEN = 5
"""The length of a block trailer (Go `blockTrailerLen`)."""
comptime FOOTER_LEN = 48
"""The length of the table footer (Go `footerLen`)."""
comptime _MAGIC: UInt64 = 0xDB4775248B80FB57


@fieldwise_init
struct BlockHandle(Equatable, ImplicitlyCopyable, Writable):
    """The location of a block in a table file (Go `blockHandle`)."""

    var offset: Int
    """The file offset of the block."""
    var length: Int
    """The length of the block, without the trailer."""

    def encode(self, mut out: List[UInt8]):
        """Appends the handle as two varints.

        Args:
            out: The destination.
        """
        put_uvarint(out, UInt64(self.offset))
        put_uvarint(out, UInt64(self.length))

    @staticmethod
    def decode(data: Span[UInt8, _], mut pos: Int) raises -> Self:
        """Reads a handle.

        Args:
            data: The input.
            pos: The offset; advanced past the handle.

        Returns:
            The handle.

        Raises:
            If the varints are malformed.
        """
        var o = read_varint_int(data, pos)
        var n = read_varint_int(data, pos)
        return Self(o, n)


struct BlockBuilder(Movable):
    """Builds one block of prefix-compressed entries (Go `blockWriter`)."""

    var restart_interval: Int
    """Entries between restart points."""
    var buf: List[UInt8]
    """The entries written so far."""
    var n_entries: Int
    """The number of entries."""
    var prev_key: List[UInt8]
    """The last key appended."""
    var _restarts: List[UInt32]

    def __init__(out self, restart_interval: Int):
        """Creates an empty block builder.

        Args:
            restart_interval: Entries between restart points.
        """
        self.restart_interval = restart_interval
        self.buf = List[UInt8]()
        self.n_entries = 0
        self.prev_key = List[UInt8]()
        self._restarts = List[UInt32]()

    def append(mut self, key: Span[UInt8, _], value: Span[UInt8, _]):
        """Appends an entry; keys must be appended in order.

        Args:
            key: The key.
            value: The value.
        """
        var shared = 0
        if self.n_entries % self.restart_interval == 0:
            self._restarts.append(UInt32(len(self.buf)))
        else:
            var n = min(len(self.prev_key), len(key))
            while shared < n and self.prev_key[shared] == key[shared]:
                shared += 1
        put_uvarint(self.buf, UInt64(shared))
        put_uvarint(self.buf, UInt64(len(key) - shared))
        put_uvarint(self.buf, UInt64(len(value)))
        self.buf.extend(key[shared:])
        self.buf.extend(value)
        self.prev_key = List[UInt8](key)
        self.n_entries += 1

    def finish(mut self):
        """Appends the restart array and count."""
        if self.n_entries == 0:
            self._restarts.append(0)
        self._restarts.append(UInt32(len(self._restarts)))
        for r in self._restarts:
            put_u32(self.buf, r)

    def reset(mut self):
        """Clears the builder for the next block (keeps `prev_key`)."""
        self.buf.clear()
        self.n_entries = 0
        self._restarts.clear()

    def bytes_len(self) -> Int:
        """Returns the size the block would have if finished now.

        Returns:
            The size in bytes.
        """
        var r = max(len(self._restarts), 1)
        return len(self.buf) + 4 * r + 4


struct TableWriter(Movable):
    """Builds a table in memory (Go `table.Writer`). Internal keys must be
    appended in increasing order; `finish` returns the file contents."""

    var _out: List[UInt8]
    var _data: BlockBuilder
    var _index: BlockBuilder
    var _filter: Optional[FilterBlockWriter]
    var _pending: Optional[BlockHandle]
    var _compression: UInt8
    var _block_size: Int
    var _n_entries: Int
    var _first_key: List[UInt8]
    var _last_key: List[UInt8]

    def __init__(
        out self,
        block_size: Int,
        restart_interval: Int,
        compression: UInt8,
        filter_bits_per_key: Int,
    ):
        """Creates a table writer.

        Args:
            block_size: The target uncompressed data block size.
            restart_interval: Entries between restart points in data blocks.
            compression: The block compression type.
            filter_bits_per_key: Bloom filter bits per key; 0 for no filter.
        """
        self._out = List[UInt8]()
        self._data = BlockBuilder(restart_interval)
        self._index = BlockBuilder(1)
        if filter_bits_per_key > 0:
            var f = FilterBlockWriter(filter_bits_per_key)
            f.flush(0)
            self._filter = f^
        else:
            self._filter = None
        self._pending = None
        self._compression = compression
        self._block_size = block_size
        self._n_entries = 0
        self._first_key = List[UInt8]()
        self._last_key = List[UInt8]()

    def entries(self) -> Int:
        """Returns the number of entries appended.

        Returns:
            The entry count.
        """
        return self._n_entries

    def bytes_len(self) -> Int:
        """Returns the bytes of blocks written so far (Go `BytesLen`).

        Returns:
            The size in bytes.
        """
        return len(self._out)

    def first_key(self) -> List[UInt8]:
        """Returns the first internal key appended.

        Returns:
            The key.
        """
        return self._first_key.copy()

    def last_key(self) -> List[UInt8]:
        """Returns the last internal key appended.

        Returns:
            The key.
        """
        return self._last_key.copy()

    def _write_block(
        mut self, mut raw: List[UInt8], kind: UInt8
    ) raises -> BlockHandle:
        var stored: List[UInt8]
        if kind == NO_COMPRESSION:
            stored = raw^
            raw = List[UInt8]()
        else:
            stored = compress(Span(raw), kind)
        stored.append(kind)
        var crc = masked_crc(Span(stored))
        put_u32(stored, crc)
        var bh = BlockHandle(len(self._out), len(stored) - BLOCK_TRAILER_LEN)
        self._out.extend(Span(stored))
        return bh

    def _flush_pending(mut self, key: Span[UInt8, _], has_key: Bool):
        if not self._pending:
            return
        var sep: Optional[List[UInt8]]
        if has_key:
            sep = separator(Span(self._data.prev_key), key)
        else:
            sep = successor(Span(self._data.prev_key))
        var hb = List[UInt8]()
        self._pending.value().encode(hb)
        if case .Some(s) = sep:
            self._index.append(Span(s), Span(hb))
        else:
            self._index.append(Span(self._data.prev_key), Span(hb))
        self._data.prev_key.clear()
        self._pending = None

    def _finish_block(mut self) raises:
        self._data.finish()
        var raw = self._data.buf^
        self._data.buf = List[UInt8]()
        self._pending = self._write_block(raw, self._compression)
        self._data.reset()
        if self._filter:
            self._filter.value().flush(len(self._out))

    def append(mut self, key: Span[UInt8, _], value: Span[UInt8, _]) raises:
        """Appends an entry (Go `Writer.Append`).

        Args:
            key: The internal key, greater than the previous one.
            value: The value.

        Raises:
            If keys are out of order.
        """
        if (
            self._n_entries > 0
            and compare_internal(Span(self._last_key), key) >= 0
        ):
            raise Error("leveldb/table: keys are not in increasing order")
        if self._n_entries == 0:
            self._first_key = List[UInt8](key)
        self._flush_pending(key, True)
        self._data.append(key, value)
        if self._filter:
            self._filter.value().add(ukey(key))
        self._last_key = List[UInt8](key)
        if self._data.bytes_len() >= self._block_size:
            self._finish_block()
        self._n_entries += 1

    def finish(mut self) raises -> List[UInt8]:
        """Writes the last data block, the filter, metaindex and index
        blocks and the footer (Go `Writer.Close`).

        Returns:
            The table file contents.

        Raises:
            If compression fails.
        """
        if self._data.n_entries > 0 or self._n_entries == 0:
            self._finish_block()
        var empty = List[UInt8]()
        self._flush_pending(Span(empty), False)
        var meta = BlockBuilder(self._data.restart_interval)
        if self._filter:
            var fb = self._filter.value().finish()
            self._filter = None
            if len(fb) > 0:
                var fbh = self._write_block(fb, NO_COMPRESSION)
                var hb = List[UInt8]()
                fbh.encode(hb)
                meta.append(String("filter.", FILTER_NAME).as_bytes(), Span(hb))
        meta.finish()
        var meta_raw = meta.buf^
        meta.buf = List[UInt8]()
        var meta_bh = self._write_block(meta_raw, self._compression)
        self._index.finish()
        var index_raw = self._index.buf^
        self._index.buf = List[UInt8]()
        var index_bh = self._write_block(index_raw, self._compression)
        var footer = List[UInt8]()
        meta_bh.encode(footer)
        index_bh.encode(footer)
        while len(footer) < FOOTER_LEN - 8:
            footer.append(0)
        for i in range(8):
            footer.append(UInt8((_MAGIC >> UInt64(8 * i)) & 0xFF))
        self._out.extend(Span(footer))
        var out = self._out^
        self._out = List[UInt8]()
        return out^


struct BlockIter(Movable):
    """Iterates the entries of one decoded block (Go `blockIter`)."""

    var _data: List[UInt8]
    var _restarts_off: Int
    var _n_restarts: Int
    var _next: Int
    var _key: List[UInt8]
    var _value_pos: Int
    var _value_len: Int
    var _valid: Bool
    var _internal: Bool

    def __init__(out self, var data: List[UInt8], internal: Bool) raises:
        """Parses a decompressed block.

        Args:
            data: The block, without trailer.
            internal: True if keys are internal keys (data and index
                blocks), False for bytewise keys (the metaindex).

        Raises:
            If the restart array is malformed.
        """
        if len(data) < 4:
            raise Error("leveldb/table: block too short")
        var n = Int(get_u32(Span(data), len(data) - 4))
        if n == 0 or (len(data) - 4) // 4 < n:
            raise Error("leveldb/table: invalid restart count")
        self._restarts_off = len(data) - 4 - 4 * n
        self._n_restarts = n
        self._data = data^
        self._next = 0
        self._key = List[UInt8]()
        self._value_pos = 0
        self._value_len = 0
        self._valid = False
        self._internal = internal

    def valid(self) -> Bool:
        """Reports whether the iterator is at an entry.

        Returns:
            True if `key` and `value` are meaningful.
        """
        return self._valid

    def key(self) -> Span[UInt8, origin_of(self._key)]:
        """Returns the current key.

        Returns:
            A view of the key.
        """
        return Span(self._key)

    def value(self) -> Span[UInt8, origin_of(self._data)]:
        """Returns the current value.

        Returns:
            A view of the value.
        """
        return Span(self._data)[
            self._value_pos : self._value_pos + self._value_len
        ]

    def _key_less(self, target: Span[UInt8, _]) -> Bool:
        if self._internal:
            return compare_internal(Span(self._key), target) < 0
        return compare_bytes(Span(self._key), target) < 0

    def _restart(self, i: Int) -> Int:
        return Int(get_u32(Span(self._data), self._restarts_off + 4 * i))

    def _decode_at(mut self, p: Int) raises:
        var pos = p
        var d = Span(self._data)
        var limit = self._restarts_off
        var shared = read_varint_int(d[:limit], pos)
        var unshared = read_varint_int(d[:limit], pos)
        var vlen = read_varint_int(d[:limit], pos)
        if shared > len(self._key) or pos + unshared + vlen > limit:
            raise Error("leveldb/table: corrupted block entry")
        self._key.resize(shared, 0)
        self._key.extend(d[pos : pos + unshared])
        self._value_pos = pos + unshared
        self._value_len = vlen
        self._next = self._value_pos + vlen
        self._valid = True

    def first(mut self) raises:
        """Moves to the first entry."""
        self._key.clear()
        self._valid = False
        self._next = 0
        self.next()

    def next(mut self) raises:
        """Moves to the next entry; becomes invalid past the last."""
        if self._next >= self._restarts_off:
            self._valid = False
            return
        self._decode_at(self._next)

    def seek(mut self, target: Span[UInt8, _]) raises:
        """Moves to the first entry whose key is not less than `target`.

        Args:
            target: The key.
        """
        # Binary search for the last restart point with a key < target.
        var lo = 0
        var hi = self._n_restarts - 1
        while lo < hi:
            var mid = (lo + hi + 1) // 2
            self._key.clear()
            self._decode_at(self._restart(mid))
            if self._key_less(target):
                lo = mid
            else:
                hi = mid - 1
        self._key.clear()
        self._next = self._restart(lo)
        self.next()
        while self._valid and self._key_less(target):
            self.next()


def read_footer(data: Span[UInt8, _]) raises -> Tuple[BlockHandle, BlockHandle]:
    """Parses a table footer.

    Args:
        data: The last `FOOTER_LEN` bytes of a table.

    Returns:
        The metaindex and index block handles.

    Raises:
        If the magic is wrong.
    """
    if len(data) != FOOTER_LEN:
        raise Error("leveldb/table: invalid footer length")
    var magic = UInt64(0)
    for i in range(8):
        magic |= UInt64(data[FOOTER_LEN - 8 + i]) << UInt64(8 * i)
    if magic != _MAGIC:
        raise Error("leveldb/table: bad magic number")
    var pos = 0
    var meta = BlockHandle.decode(data, pos)
    var index = BlockHandle.decode(data, pos)
    return (meta, index)


def check_block(
    stored: Span[UInt8, _], bh: BlockHandle, verify: Bool
) raises -> List[UInt8]:
    """Checks a stored block's trailer and decompresses it.

    Args:
        stored: The block followed by its trailer.
        bh: The handle the block was read with.
        verify: Whether to verify the checksum.

    Returns:
        The raw block.

    Raises:
        If the block is short, its checksum mismatches or it does not
        decompress.
    """
    if len(stored) != bh.length + BLOCK_TRAILER_LEN:
        raise Error("leveldb/table: truncated block")
    if verify:
        var want = get_u32(stored, bh.length + 1)
        if masked_crc(stored[: bh.length + 1]) != want:
            raise Error(
                t"leveldb/table: checksum mismatch in block at {bh.offset}"
            )
    return decompress(stored[: bh.length], stored[bh.length])


struct Table(Copyable, Movable):
    """An open table: its index, filter and key range (Go `table.Reader`
    plus `tFile`). Data blocks are read from the file on demand."""

    var num: Int
    """The file number."""
    var size: Int
    """The file size."""
    var path: String
    """The file path."""
    var imin: List[UInt8]
    """The smallest internal key."""
    var imax: List[UInt8]
    """The largest internal key."""
    var _index_keys: List[List[UInt8]]
    var _index_handles: List[BlockHandle]
    var _filter: Optional[FilterBlockReader]

    def __init__(
        out self,
        num: Int,
        size: Int,
        var path: String,
        var imin: List[UInt8],
        var imax: List[UInt8],
    ) raises:
        """Opens a table and loads its index and filter.

        Args:
            num: The file number.
            size: The file size recorded in the manifest.
            path: The file path.
            imin: The smallest internal key, from the manifest.
            imax: The largest internal key, from the manifest.

        Raises:
            If the file cannot be read or its footer, index or metaindex is
            corrupt.
        """
        var f = open_read(path)
        var actual = f.size()
        if actual < FOOTER_LEN:
            raise Error(t"leveldb/table: {path} is too short")
        var buf = List[UInt8]()
        _ = f.read_at(buf, actual - FOOTER_LEN, FOOTER_LEN)
        var handles = read_footer(Span(buf))
        var index = BlockIter(_read_block(f, handles[1], True), True)
        var keys = List[List[UInt8]]()
        var bhs = List[BlockHandle]()
        index.first()
        while index.valid():
            keys.append(List[UInt8](index.key()))
            var p = 0
            bhs.append(BlockHandle.decode(index.value(), p))
            index.next()
        var filter: Optional[FilterBlockReader] = None
        var meta = BlockIter(_read_block(f, handles[0], True), False)
        meta.first()
        while meta.valid():
            var k = meta.key()
            if (
                compare_bytes(k, String("filter.", FILTER_NAME).as_bytes()) == 0
                or compare_bytes(
                    k, String("filter.", GO_FILTER_NAME).as_bytes()
                )
                == 0
            ):
                var p = 0
                var fbh = BlockHandle.decode(meta.value(), p)
                filter = FilterBlockReader(_read_block(f, fbh, True))
                break
            meta.next()
        self.num = num
        self.size = size
        self.path = path^
        self.imin = imin^
        self.imax = imax^
        self._index_keys = keys^
        self._index_handles = bhs^
        self._filter = filter^

    def blocks(self) -> Int:
        """Returns the number of data blocks.

        Returns:
            The block count.
        """
        return len(self._index_handles)

    def block_handle(self, i: Int) -> BlockHandle:
        """Returns the handle of data block `i`.

        Args:
            i: The block index.

        Returns:
            The handle.
        """
        return self._index_handles[i]

    def find_block(self, ikey: Span[UInt8, _]) -> Int:
        """Returns the first data block whose index key is not less than
        `ikey`, which is the only block that can hold it.

        Args:
            ikey: The internal key.

        Returns:
            The block index, or `blocks()` if every key is smaller.
        """
        var lo = 0
        var hi = len(self._index_keys)
        while lo < hi:
            var mid = (lo + hi) // 2
            if compare_internal(Span(self._index_keys[mid]), ikey) < 0:
                lo = mid + 1
            else:
                hi = mid
        return lo

    def read_block(self, i: Int) raises -> BlockIter:
        """Reads and decodes data block `i`.

        Args:
            i: The block index.

        Returns:
            An iterator over the block, not positioned.

        Raises:
            If the block cannot be read or is corrupt.
        """
        var f = open_read(self.path)
        return BlockIter(_read_block(f, self._index_handles[i], True), True)

    def get(
        self, ikey: Span[UInt8, _]
    ) raises -> Optional[Tuple[List[UInt8], List[UInt8]]]:
        """Finds the first entry not less than `ikey` with the same user key.

        Args:
            ikey: A seek key (user key with the maximum sequence number).

        Returns:
            The entry's internal key and value, or None.

        Raises:
            If a block is corrupt.
        """
        var i = self.find_block(ikey)
        if i >= len(self._index_handles):
            return None
        if self._filter:
            if not self._filter.value().may_contain(
                self._index_handles[i].offset, ukey(ikey)
            ):
                return None
        var it = self.read_block(i)
        it.seek(ikey)
        if not it.valid():
            return None
        if compare_bytes(ukey(it.key()), ukey(ikey)) != 0:
            return None
        return (List[UInt8](it.key()), List[UInt8](it.value()))


def _read_block(f: File, bh: BlockHandle, verify: Bool) raises -> List[UInt8]:
    var stored = List[UInt8]()
    _ = f.read_at(stored, bh.offset, bh.length + BLOCK_TRAILER_LEN)
    return check_block(Span(stored), bh, verify)
