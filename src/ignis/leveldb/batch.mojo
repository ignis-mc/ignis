"""Write batches, ported from goleveldb `batch.go`.

A batch's journal record is a 12-byte header (sequence number u64 LE, record
count u32 LE) followed by records: the key type byte, the key with a varint
length and, for puts, the value with a varint length.
"""

from .key import KEY_TYPE_DEL, KEY_TYPE_VAL
from .util import (
    get_u32,
    get_u64,
    put_u32,
    put_u64,
    put_uvarint,
    read_varint_int,
)

comptime BATCH_HEADER_LEN = 12
"""The length of a batch header (Go `batchHeaderLen`)."""


@fieldwise_init
struct BatchRecord(Copyable, Movable):
    """One decoded batch record: offsets into the batch data."""

    var key_type: UInt8
    """`KEY_TYPE_DEL` or `KEY_TYPE_VAL`."""
    var key_pos: Int
    """The offset of the key."""
    var key_len: Int
    """The length of the key."""
    var value_pos: Int
    """The offset of the value (0 for deletions)."""
    var value_len: Int
    """The length of the value (0 for deletions)."""


struct Batch(Copyable, Defaultable, Movable, Sized):
    """A sequence of puts and deletes applied atomically (Go `Batch`)."""

    var _data: List[UInt8]
    var _len: Int
    var _internal_len: Int

    def __init__(out self):
        """Creates an empty batch."""
        self._data = List[UInt8]()
        self._len = 0
        self._internal_len = 0

    def __len__(self) -> Int:
        """Returns the number of records.

        Returns:
            The record count.
        """
        return self._len

    def _append(
        mut self,
        kt: UInt8,
        key: Span[mut=False, UInt8, _],
        value: Span[mut=False, UInt8, _],
    ):
        self._data.append(kt)
        put_uvarint(self._data, UInt64(len(key)))
        self._data.extend(key)
        if kt == KEY_TYPE_VAL:
            put_uvarint(self._data, UInt64(len(value)))
            self._data.extend(value)
        self._len += 1
        self._internal_len += len(key) + len(value) + 8

    def put(
        mut self,
        key: Span[mut=False, UInt8, _],
        value: Span[mut=False, UInt8, _],
    ):
        """Appends a put of `key` to `value` (Go `Batch.Put`).

        Args:
            key: The key.
            value: The value.
        """
        self._append(KEY_TYPE_VAL, key, value)

    def delete(mut self, key: Span[mut=False, UInt8, _]):
        """Appends a delete of `key` (Go `Batch.Delete`).

        Args:
            key: The key.
        """
        var empty = List[UInt8]()
        self._append(KEY_TYPE_DEL, key, Span(empty))

    def reset(mut self):
        """Removes every record (Go `Batch.Reset`)."""
        self._data.clear()
        self._len = 0
        self._internal_len = 0

    def internal_len(self) -> Int:
        """Returns the memtable size the batch adds: keys, values and 8 bytes
        per record.

        Returns:
            The size in bytes.
        """
        return self._internal_len

    def data(self) -> Span[UInt8, origin_of(self._data)]:
        """Returns the encoded records, without the header.

        Returns:
            A view of the records.
        """
        return Span(self._data)

    def encode_record(self, seq: UInt64, mut out: List[UInt8]):
        """Appends the journal record: header with `seq` and the records.

        Args:
            seq: The sequence number of the first record.
            out: The destination.
        """
        put_u64(out, seq)
        put_u32(out, UInt32(self._len))
        out.extend(Span(self._data))


def decode_batch_header(
    data: Span[mut=False, UInt8, _]
) raises -> Tuple[UInt64, Int]:
    """Reads a batch header (Go `decodeBatchHeader`).

    Args:
        data: The journal record.

    Returns:
        The sequence number and the record count.

    Raises:
        If the record is shorter than the header.
    """
    if len(data) < BATCH_HEADER_LEN:
        raise Error("leveldb: batch corrupted: too short")
    return (get_u64(data, 0), Int(get_u32(data, 8)))


def decode_batch(data: Span[mut=False, UInt8, _]) raises -> List[BatchRecord]:
    """Splits batch records (without the header) (Go `decodeBatch`).

    Args:
        data: The records.

    Returns:
        The records in order.

    Raises:
        If a record is malformed.
    """
    var out = List[BatchRecord]()
    var o = 0
    while o < len(data):
        var kt = data[o]
        if kt > KEY_TYPE_VAL:
            raise Error(t"leveldb: batch corrupted: invalid type {kt}")
        o += 1
        var klen = read_varint_int(data, o)
        if o + klen > len(data):
            raise Error("leveldb: batch corrupted: invalid key length")
        var kpos = o
        o += klen
        var vpos = 0
        var vlen = 0
        if kt == KEY_TYPE_VAL:
            vlen = read_varint_int(data, o)
            if o + vlen > len(data):
                raise Error("leveldb: batch corrupted: invalid value length")
            vpos = o
            o += vlen
        out.append(BatchRecord(kt, kpos, klen, vpos, vlen))
    return out^
