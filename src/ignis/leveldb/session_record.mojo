"""Version edits as stored in the MANIFEST, ported from goleveldb
`session_record.go`. Field numbers are part of the format and match C++
LevelDB's `VersionEdit`."""

from .util import put_uvarint, read_uvarint, read_varint_int

comptime REC_COMPARER = 1
"""The comparator name."""
comptime REC_JOURNAL_NUM = 2
"""The journal file number."""
comptime REC_NEXT_FILE_NUM = 3
"""The next file number."""
comptime REC_SEQ_NUM = 4
"""The last sequence number."""
comptime REC_COMP_PTR = 5
"""A compaction pointer."""
comptime REC_DEL_TABLE = 6
"""A removed table."""
comptime REC_ADD_TABLE = 7
"""An added table."""
comptime REC_PREV_JOURNAL_NUM = 9
"""The previous journal file number."""


@fieldwise_init
struct AddedTable(Copyable, Movable):
    """A table added to a level (Go `atRecord`)."""

    var level: Int
    """The level."""
    var num: Int
    """The file number."""
    var size: Int
    """The file size."""
    var imin: List[UInt8]
    """The smallest internal key."""
    var imax: List[UInt8]
    """The largest internal key."""


@fieldwise_init
struct CompPtr(Copyable, Movable):
    """Where the next compaction of a level starts (Go `cpRecord`)."""

    var level: Int
    """The level."""
    var ikey: List[UInt8]
    """The largest internal key of the last compaction's input."""


struct SessionRecord(Copyable, Defaultable, Movable):
    """One version edit (Go `sessionRecord`)."""

    var comparer: Optional[String]
    """The comparator name, if recorded."""
    var journal_num: Optional[Int]
    """The current journal file number, if recorded."""
    var prev_journal_num: Optional[Int]
    """The previous journal file number, if recorded."""
    var next_file_num: Optional[Int]
    """The next file number, if recorded."""
    var seq_num: Optional[UInt64]
    """The last sequence number, if recorded."""
    var comp_ptrs: List[CompPtr]
    """Compaction pointers."""
    var deleted: List[Tuple[Int, Int]]
    """Removed tables as (level, file number)."""
    var added: List[AddedTable]
    """Added tables."""

    def __init__(out self):
        """Creates an empty edit."""
        self.comparer = None
        self.journal_num = None
        self.prev_journal_num = None
        self.next_file_num = None
        self.seq_num = None
        self.comp_ptrs = List[CompPtr]()
        self.deleted = List[Tuple[Int, Int]]()
        self.added = List[AddedTable]()

    def encode(self, mut out: List[UInt8]):
        """Appends the edit in goleveldb's field order (Go
        `sessionRecord.encode`)."""
        if case .Some(c) = self.comparer:
            put_uvarint(out, REC_COMPARER)
            put_uvarint(out, UInt64(c.byte_length()))
            out.extend(c.as_bytes())
        if case .Some(n) = self.journal_num:
            put_uvarint(out, REC_JOURNAL_NUM)
            put_uvarint(out, UInt64(n))
        if case .Some(n) = self.prev_journal_num:
            put_uvarint(out, REC_PREV_JOURNAL_NUM)
            put_uvarint(out, UInt64(n))
        if case .Some(n) = self.next_file_num:
            put_uvarint(out, REC_NEXT_FILE_NUM)
            put_uvarint(out, UInt64(n))
        if case .Some(s) = self.seq_num:
            put_uvarint(out, REC_SEQ_NUM)
            put_uvarint(out, s)
        for cp in self.comp_ptrs:
            put_uvarint(out, REC_COMP_PTR)
            put_uvarint(out, UInt64(cp.level))
            put_uvarint(out, UInt64(len(cp.ikey)))
            out.extend(Span(cp.ikey))
        for d in self.deleted:
            put_uvarint(out, REC_DEL_TABLE)
            put_uvarint(out, UInt64(d[0]))
            put_uvarint(out, UInt64(d[1]))
        for t in self.added:
            put_uvarint(out, REC_ADD_TABLE)
            put_uvarint(out, UInt64(t.level))
            put_uvarint(out, UInt64(t.num))
            put_uvarint(out, UInt64(t.size))
            put_uvarint(out, UInt64(len(t.imin)))
            out.extend(Span(t.imin))
            put_uvarint(out, UInt64(len(t.imax)))
            out.extend(Span(t.imax))

    @staticmethod
    def decode(data: Span[mut=False, UInt8, _]) raises -> Self:
        """Parses an edit (Go `sessionRecord.decode`)."""
        var r = Self()
        var pos = 0
        while pos < len(data):
            var tag = read_uvarint(data, pos)
            if tag == REC_COMPARER:
                var b = _read_bytes(data, pos)
                r.comparer = String(from_utf8_lossy=Span(b))
            elif tag == REC_JOURNAL_NUM:
                r.journal_num = read_varint_int(data, pos)
            elif tag == REC_PREV_JOURNAL_NUM:
                r.prev_journal_num = read_varint_int(data, pos)
            elif tag == REC_NEXT_FILE_NUM:
                r.next_file_num = read_varint_int(data, pos)
            elif tag == REC_SEQ_NUM:
                r.seq_num = read_uvarint(data, pos)
            elif tag == REC_COMP_PTR:
                var level = read_varint_int(data, pos)
                r.comp_ptrs.append(CompPtr(level, _read_bytes(data, pos)))
            elif tag == REC_DEL_TABLE:
                var level = read_varint_int(data, pos)
                var num = read_varint_int(data, pos)
                r.deleted.append((level, num))
            elif tag == REC_ADD_TABLE:
                var level = read_varint_int(data, pos)
                var num = read_varint_int(data, pos)
                var size = read_varint_int(data, pos)
                var imin = _read_bytes(data, pos)
                var imax = _read_bytes(data, pos)
                r.added.append(AddedTable(level, num, size, imin^, imax^))
            else:
                # goleveldb leaves unknown tags unread, which desynchronises
                # the record; failing is the honest equivalent.
                raise Error(t"leveldb: manifest corrupted: unknown field {tag}")
        return r^


def _read_bytes(
    data: Span[mut=False, UInt8, _], mut pos: Int
) raises -> List[UInt8]:
    var n = read_varint_int(data, pos)
    if pos + n > len(data):
        raise Error("leveldb: manifest corrupted: short read")
    var out = List[UInt8](data[pos : pos + n])
    pos += n
    return out^
