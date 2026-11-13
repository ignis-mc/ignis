"""The database, ported from goleveldb `db.go`, `db_write.go`,
`db_compaction.go`, `db_util.go`, `session.go` and `session_util.go`.

Opening follows goleveldb: lock `LOCK`, find the manifest through
`CURRENT`, rebuild the version from its edits, replay every journal from
the manifest's journal number into memtables (flushing them to level-0
tables), then start a new journal and write a new manifest that snapshots
the version, and remove obsolete files. A crash at any point leaves either
the old or the new manifest in charge with every file it needs.

Writes append the batch to the journal and insert it into the memtable. A
full memtable is flushed synchronously: a new journal is started, the
memtable is written as a level-0 table, the manifest records both, and the
old journal is removed. After a flush, up to two compaction steps run
(`compact_once`), which keeps level 0 and the level sizes bounded the way
goleveldb's background compaction does, just in the caller's thread.
"""

from ..internal.fs import (
    File,
    create,
    join,
    make_dir_all,
    open_read,
    open_rw,
    read_file,
    remove,
    write_file,
)
from .batch import BATCH_HEADER_LEN, Batch, decode_batch, decode_batch_header
from .iterator import Iterator, MemStream, MergedStream, TableStream
from .journal import JournalReader, JournalWriter
from .key import (
    COMPARER_NAME,
    KEY_MAX_SEQ,
    KEY_TYPE_DEL,
    KEY_TYPE_VAL,
    compare_internal,
    internal_key,
    key_num,
    key_type,
    make_internal_key,
    ukey,
)
from .memdb import MemDB
from .options import Options
from .session_record import AddedTable, CompPtr, SessionRecord
from .storage import (
    TYPE_JOURNAL,
    TYPE_MANIFEST,
    TYPE_TABLE,
    TYPE_TEMP,
    FileDesc,
    file_name,
    get_meta,
    list_files,
    set_meta,
    table_path,
)
from .table import Table, TableWriter
from .util import compare_bytes
from .version import NUM_LEVELS, Version, open_table


def _not_found(e: Error) -> Bool:
    return "errno 2" in String(e)


struct _Recovered(Movable):
    var version: Version
    var journal_num: Int
    var prev_journal_num: Int
    var next_file_num: Int
    var seq: UInt64
    var comp_ptrs: List[List[UInt8]]

    def __init__(out self):
        self.version = Version()
        self.journal_num = 0
        self.prev_journal_num = 0
        self.next_file_num = 0
        self.seq = 0
        self.comp_ptrs = List[List[UInt8]]()
        for _ in range(NUM_LEVELS):
            self.comp_ptrs.append(List[UInt8]())

    def into_parts(deinit self) -> Tuple[Version, List[List[UInt8]]]:
        return (self.version^, self.comp_ptrs^)


def _recover_manifest(
    dir: String, fd: FileDesc, strict: Bool
) raises -> _Recovered:
    # Go session.recover: replays the edits into a staging set per level.
    var r = _Recovered()
    var jr = JournalReader(read_file(join(dir, file_name(fd))))
    var staged = List[List[AddedTable]]()
    for _ in range(NUM_LEVELS):
        staged.append(List[AddedTable]())
    var comparer: Optional[String] = None
    var have_next = False
    var have_journal = False
    var have_seq = False
    while True:
        var rec_bytes = jr.next()
        if not rec_bytes:
            break
        var rec: SessionRecord
        try:
            rec = SessionRecord.decode(Span(rec_bytes.value()))
        except e:
            if strict:
                raise Error(t"leveldb: manifest {file_name(fd)}: {e}")
            continue
        if case .Some(c) = rec.comparer:
            comparer = c
        if case .Some(n) = rec.journal_num:
            r.journal_num = n
            have_journal = True
        if case .Some(n) = rec.prev_journal_num:
            r.prev_journal_num = n
        if case .Some(n) = rec.next_file_num:
            r.next_file_num = n
            have_next = True
        if case .Some(s) = rec.seq_num:
            r.seq = s
            have_seq = True
        for cp in rec.comp_ptrs:
            if cp.level >= 0 and cp.level < NUM_LEVELS:
                r.comp_ptrs[cp.level] = cp.ikey.copy()
        for d in rec.deleted:
            if d[0] < 0 or d[0] >= NUM_LEVELS:
                raise Error(t"leveldb: manifest: invalid level {d[0]}")
            ref l = staged[d[0]]
            for i in range(len(l)):
                if l[i].num == d[1]:
                    _ = l.pop(i)
                    break
        for a in rec.added:
            if a.level < 0 or a.level >= NUM_LEVELS:
                raise Error(t"leveldb: manifest: invalid level {a.level}")
            ref l = staged[a.level]
            for i in range(len(l)):
                if l[i].num == a.num:
                    _ = l.pop(i)
                    break
            staged[a.level].append(a.copy())
    if strict and jr.dropped > 0:
        raise Error(t"leveldb: manifest {file_name(fd)} is corrupted")
    if not comparer:
        raise Error("leveldb: manifest corrupted: comparer missing")
    if comparer.value() != COMPARER_NAME:
        raise Error(
            t"leveldb: manifest corrupted: comparer mismatch: want"
            t" '{COMPARER_NAME}', got '{comparer.value()}'"
        )
    if not have_next:
        raise Error("leveldb: manifest corrupted: next-file-num missing")
    if not have_journal:
        raise Error("leveldb: manifest corrupted: journal-file-num missing")
    if not have_seq:
        raise Error("leveldb: manifest corrupted: seq-num missing")
    for level in range(NUM_LEVELS):
        for a in staged[level]:
            r.version.add_at(level, open_table(dir, a))
    return r^


struct DB(Movable):
    """A LevelDB database in a directory (Go `leveldb.DB`)."""

    var _dir: String
    var _opts: Options
    var _lock: File
    var _version: Version
    var _mem: MemDB
    var _journal: File
    var _journal_writer: JournalWriter
    var _journal_num: Int
    var _manifest: File
    var _manifest_writer: JournalWriter
    var _manifest_num: Int
    var _next_file_num: Int
    var _seq: UInt64
    var _comp_ptrs: List[List[UInt8]]

    def __init__(
        out self, dir: StringSlice, var opts: Options = Options()
    ) raises:
        """Opens or creates the database in `dir` (Go `leveldb.OpenFile`).

        Args:
            dir: The database directory; created if missing.
            opts: The options.

        Raises:
            If the directory is locked by another process, the manifest or a
            table is corrupt or missing, or a file cannot be written.
        """
        var d = String(dir)
        make_dir_all(d)
        var lock = open_rw(join(d, "LOCK"))
        lock.try_lock()

        var files = list_files(d)
        var max_num = 0
        for f in files:
            max_num = max(max_num, f[0].num)
        var meta = get_meta(d)
        var rec: _Recovered
        if case .Some(fd) = meta:
            rec = _recover_manifest(d, fd, opts.strict)
        else:
            for f in files:
                if f[0].type != TYPE_TEMP:
                    raise Error(
                        "leveldb: corrupted: no valid CURRENT, but database"
                        " files exist"
                    )
            rec = _Recovered()
        var next_file = max(rec.next_file_num, max_num + 1)
        var seq = rec.seq
        var journal_floor = rec.journal_num
        var prev_journal = rec.prev_journal_num
        var parts = rec^.into_parts()
        var version = parts[0].copy()
        var comp_ptrs = parts[1].copy()
        _ = parts^

        # Go DB.recoverJournal.
        var journals = List[Int]()
        for f in files:
            if f[0].type == TYPE_JOURNAL and (
                f[0].num >= journal_floor or f[0].num == prev_journal
            ):
                journals.append(f[0].num)
        sort(journals)
        var mem = MemDB()
        for jn in journals:
            var jr = JournalReader(
                read_file(join(d, file_name(FileDesc(TYPE_JOURNAL, jn))))
            )
            while True:
                var r = jr.next()
                if not r:
                    break
                try:
                    seq = _apply_batch_record(Span(r.value()), seq, mem)
                except e:
                    if opts.strict:
                        raise e^
                    continue
                if mem.size() >= opts.write_buffer:
                    var t = _flush_memdb(d, mem, next_file, opts)
                    next_file += 1
                    if t:
                        version.add_at(0, open_table(d, t.value()))
                    mem = MemDB()
            if opts.strict and jr.dropped > 0:
                raise Error(t"leveldb: journal {jn} is corrupted")
            if len(mem) > 0:
                var t = _flush_memdb(d, mem, next_file, opts)
                next_file += 1
                if t:
                    version.add_at(0, open_table(d, t.value()))
                mem = MemDB()

        var journal_num = next_file
        next_file += 1
        var journal = create(
            join(d, file_name(FileDesc(TYPE_JOURNAL, journal_num)))
        )
        var manifest_num = next_file
        next_file += 1
        var snap = SessionRecord()
        snap.comparer = String(COMPARER_NAME)
        snap.journal_num = journal_num
        snap.next_file_num = next_file
        snap.seq_num = seq
        for level in range(NUM_LEVELS):
            if len(comp_ptrs[level]) > 0:
                snap.comp_ptrs.append(CompPtr(level, comp_ptrs[level].copy()))
            for t in version.levels[level]:
                snap.added.append(
                    AddedTable(
                        level, t.num, t.size, t.imin.copy(), t.imax.copy()
                    )
                )
        var mfd = FileDesc(TYPE_MANIFEST, manifest_num)
        var manifest = create(join(d, file_name(mfd)))
        var mw = JournalWriter()
        var body = List[UInt8]()
        snap.encode(body)
        var framed = List[UInt8]()
        mw.append(Span(body), framed)
        manifest.write_all(Span(framed))
        manifest.sync()
        set_meta(d, mfd)

        # Go DB.checkAndCleanFiles.
        for f in list_files(d):
            var keep = True
            if f[0].type == TYPE_MANIFEST:
                keep = f[0].num >= manifest_num
            elif f[0].type == TYPE_JOURNAL:
                keep = f[0].num >= journal_num
            elif f[0].type == TYPE_TABLE:
                keep = version.has_table(f[0].num)
            elif f[0].type == TYPE_TEMP:
                keep = False
            if not keep:
                remove(join(d, f[1]))

        self._dir = d^
        self._opts = opts^
        self._lock = lock^
        self._version = version^
        self._mem = MemDB()
        self._journal = journal^
        self._journal_writer = JournalWriter()
        self._journal_num = journal_num
        self._manifest = manifest^
        self._manifest_writer = mw^
        self._manifest_num = manifest_num
        self._next_file_num = next_file
        self._seq = seq
        self._comp_ptrs = comp_ptrs^

    def dir(self) -> String:
        """Returns the database directory.

        Returns:
            The path.
        """
        return self._dir

    def seq(self) -> UInt64:
        """Returns the last sequence number used.

        Returns:
            The sequence number.
        """
        return self._seq

    def version(self) -> ref[self._version] Version:
        """Returns the current tables of every level.

        Returns:
            A reference to the version.
        """
        return self._version

    def memtable_size(self) -> Int:
        """Returns the bytes held by the memtable.

        Returns:
            The size in bytes.
        """
        return self._mem.size()

    # ===------------------------------------------------------------------=== #
    # Reads
    # ===------------------------------------------------------------------=== #

    def get(self, key: Span[UInt8, _]) raises -> Optional[List[UInt8]]:
        """Returns the value of a key (Go `DB.Get`; None replaces
        `ErrNotFound`).

        Args:
            key: The user key.

        Returns:
            The value, or None if the key is absent or deleted.

        Raises:
            If a table is corrupt or unreadable.
        """
        var ik = internal_key(key, KEY_MAX_SEQ, KEY_TYPE_VAL)
        var node = self._mem.find_ge(Span(ik))
        if node != 0:
            var k = self._mem.key_at(node)
            if compare_bytes(ukey(k), key) == 0:
                if key_type(k) == KEY_TYPE_DEL:
                    return None
                return List[UInt8](self._mem.value_at(node))
        var best: Optional[Tuple[List[UInt8], List[UInt8]]] = None
        for t in self._version.levels[0]:
            if compare_bytes(ukey(Span(t.imin)), key) > 0:
                continue
            if compare_bytes(ukey(Span(t.imax)), key) < 0:
                continue
            var r = t.get(Span(ik))
            if r:
                if not best or key_num(Span(r.value()[0])) > key_num(
                    Span(best.value()[0])
                ):
                    best = r^
        if case .Some(b) = best:
            if key_type(Span(b[0])) == KEY_TYPE_DEL:
                return None
            return b[1].copy()
        for level in range(1, NUM_LEVELS):
            ref l = self._version.levels[level]
            var lo = 0
            var hi = len(l)
            while lo < hi:
                var mid = (lo + hi) // 2
                if compare_internal(Span(l[mid].imax), Span(ik)) < 0:
                    lo = mid + 1
                else:
                    hi = mid
            if lo >= len(l):
                continue
            if compare_bytes(ukey(Span(l[lo].imin)), key) > 0:
                continue
            var r = l[lo].get(Span(ik))
            if case .Some(e) = r:
                if key_type(Span(e[0])) == KEY_TYPE_DEL:
                    return None
                return e[1].copy()
        return None

    def has(self, key: Span[UInt8, _]) raises -> Bool:
        """Reports whether a key is present (Go `DB.Has`).

        Args:
            key: The user key.

        Returns:
            True if present.

        Raises:
            If a table is corrupt or unreadable.
        """
        return Bool(self.get(key))

    def new_iterator(self) -> Iterator:
        """Returns an iterator over every live key in order (Go
        `DB.NewIterator(nil, nil)`). It reads a copy of the memtable and of
        the table list; compactions run after it is created may remove
        files it reads.

        Returns:
            The iterator, before the first entry.
        """
        var tables = List[TableStream]()
        for t in self._version.levels[0]:
            tables.append(TableStream([t.copy()]))
        for level in range(1, NUM_LEVELS):
            if len(self._version.levels[level]) > 0:
                tables.append(TableStream(self._version.levels[level].copy()))
        return Iterator(MergedStream(MemStream(self._mem.copy()), tables^))

    # ===------------------------------------------------------------------=== #
    # Writes
    # ===------------------------------------------------------------------=== #

    def put(mut self, key: Span[UInt8, _], value: Span[UInt8, _]) raises:
        """Sets a key (Go `DB.Put`).

        Args:
            key: The user key.
            value: The value.

        Raises:
            If the journal or a flush cannot be written.
        """
        var b = Batch()
        b.put(key, value)
        self.write(b)

    def delete(mut self, key: Span[UInt8, _]) raises:
        """Deletes a key (Go `DB.Delete`).

        Args:
            key: The user key.

        Raises:
            If the journal or a flush cannot be written.
        """
        var b = Batch()
        b.delete(key)
        self.write(b)

    def write(mut self, batch: Batch) raises:
        """Applies a batch atomically (Go `DB.Write`): one journal record,
        then the memtable.

        Args:
            batch: The batch.

        Raises:
            If the journal or a flush cannot be written.
        """
        if len(batch) == 0:
            return
        if (
            len(self._mem) > 0
            and self._mem.size() + batch.internal_len()
            > self._opts.write_buffer
        ):
            self.flush()
        var seq = self._seq + 1
        var rec = List[UInt8](capacity=BATCH_HEADER_LEN + len(batch.data()))
        batch.encode_record(seq, rec)
        var framed = List[UInt8](capacity=len(rec) + 64)
        self._journal_writer.append(Span(rec), framed)
        self._journal.write_all(Span(framed))
        if self._opts.sync:
            self._journal.sync()
        self._seq = _apply_batch_record(Span(rec), self._seq, self._mem)
        if self._mem.size() >= self._opts.write_buffer:
            self.flush()

    def sync(self) raises:
        """Flushes the journal to disk.

        Raises:
            If `fsync` fails.
        """
        self._journal.sync()

    # ===------------------------------------------------------------------=== #
    # Flush and compaction
    # ===------------------------------------------------------------------=== #

    def _alloc(mut self) -> Int:
        var n = self._next_file_num
        self._next_file_num += 1
        return n

    def _commit(mut self, mut rec: SessionRecord) raises:
        # Go session.flushManifest: append the edit, sync, apply it.
        rec.next_file_num = self._next_file_num
        var body = List[UInt8]()
        rec.encode(body)
        var framed = List[UInt8]()
        self._manifest_writer.append(Span(body), framed)
        self._manifest.write_all(Span(framed))
        self._manifest.sync()
        self._version.apply(rec, self._dir)
        for cp in rec.comp_ptrs:
            self._comp_ptrs[cp.level] = cp.ikey.copy()

    def flush(mut self) raises:
        """Writes the memtable to a level-0 table and starts a new journal
        (Go `DB.rotateMem` and `memCompaction`), then runs up to two
        compaction steps.

        Raises:
            If a file cannot be written.
        """
        var old_journal = self._journal_num
        var new_num = self._alloc()
        var journal = create(
            join(self._dir, file_name(FileDesc(TYPE_JOURNAL, new_num)))
        )
        var rec = SessionRecord()
        if len(self._mem) > 0:
            var num = self._alloc()
            var t = _flush_memdb(self._dir, self._mem, num, self._opts)
            if case .Some(a) = t:
                rec.added.append(a.copy())
        rec.journal_num = new_num
        rec.seq_num = self._seq
        self._commit(rec)
        self._journal = journal^
        self._journal_writer = JournalWriter()
        self._journal_num = new_num
        self._mem = MemDB()
        remove(join(self._dir, file_name(FileDesc(TYPE_JOURNAL, old_journal))))
        for _ in range(2):
            if not self.compact_once():
                break

    def _pick_level(self) -> Int:
        # Go version.computeCompaction: the level with the highest score >= 1.
        var best = -1
        var best_score = 1.0
        var l0 = Float64(len(self._version.levels[0])) / Float64(
            self._opts.compaction_l0_trigger
        )
        if l0 >= best_score:
            best = 0
            best_score = l0
        var limit = Float64(self._opts.compaction_total_size)
        for level in range(1, NUM_LEVELS - 1):
            var score = Float64(self._version.level_size(level)) / limit
            if score > best_score or (score >= 1.0 and best < 0):
                best = level
                best_score = score
            limit *= 10
        return best

    def compact_once(mut self) raises -> Bool:
        """Runs one compaction step if a level needs it (Go
        `tableAutoCompaction`): all level-0 tables into level 1 when there
        are `compaction_l0_trigger` of them, otherwise one table of the
        fullest level into the next. Callers that want bounded pauses can
        call this from an idle loop instead of relying on the automatic
        steps after a flush.

        Returns:
            True if a compaction ran.

        Raises:
            If a file cannot be read or written.
        """
        var level = self._pick_level()
        if level < 0:
            return False
        var inputs0 = List[Table]()
        if level == 0:
            inputs0 = self._version.levels[0].copy()
        else:
            ref l = self._version.levels[level]
            var pick = 0
            ref ptr = self._comp_ptrs[level]
            if len(ptr) > 0:
                while (
                    pick < len(l)
                    and compare_internal(Span(l[pick].imax), Span(ptr)) <= 0
                ):
                    pick += 1
                if pick >= len(l):
                    pick = 0
            inputs0.append(l[pick].copy())
        self._compact(level, inputs0^, level + 1)
        return True

    def compact_all(mut self) raises:
        """Flushes the memtable and merges every table into the deepest
        non-empty level (at least 1), dropping overwritten versions and
        deletion markers (Go `DB.CompactRange` over the whole key space).

        Raises:
            If a file cannot be read or written.
        """
        if len(self._mem) > 0:
            self.flush()
        var out_level = 1
        for level in range(1, NUM_LEVELS):
            if len(self._version.levels[level]) > 0:
                out_level = level
        var rec = SessionRecord()
        var streams = List[TableStream]()
        var inputs = List[Tuple[Int, Int, String]]()
        for t in self._version.levels[0]:
            streams.append(TableStream([t.copy()]))
            inputs.append((0, t.num, t.path))
        for level in range(1, NUM_LEVELS):
            if len(self._version.levels[level]) > 0:
                streams.append(TableStream(self._version.levels[level].copy()))
                for t in self._version.levels[level]:
                    inputs.append((level, t.num, t.path))
        if len(inputs) == 0:
            return
        var m = MergedStream(None, streams^)
        m.first()
        self._merge_into(m, out_level, rec)
        for i in inputs:
            rec.deleted.append((i[0], i[1]))
        self._commit(rec)
        for i in inputs:
            remove(i[2])

    def _compact(
        mut self, level: Int, var inputs0: List[Table], out_level: Int
    ) raises:
        # Go DB.tableCompaction.
        var umin = List[UInt8](ukey(Span(inputs0[0].imin)))
        var umax = List[UInt8](ukey(Span(inputs0[0].imax)))
        var imax = inputs0[0].imax.copy()
        for t in inputs0:
            if compare_bytes(ukey(Span(t.imin)), Span(umin)) < 0:
                umin = List[UInt8](ukey(Span(t.imin)))
            if compare_bytes(ukey(Span(t.imax)), Span(umax)) > 0:
                umax = List[UInt8](ukey(Span(t.imax)))
            if compare_internal(Span(t.imax), Span(imax)) > 0:
                imax = t.imax.copy()
        var inputs1 = List[Table]()
        for i in self._version.overlapping(out_level, Span(umin), Span(umax)):
            inputs1.append(self._version.levels[out_level][i].copy())
        var rec = SessionRecord()
        rec.comp_ptrs.append(CompPtr(level, imax^))
        if len(inputs0) == 1 and len(inputs1) == 0:
            # Trivial move (Go `trivial` compaction).
            ref t = inputs0[0]
            rec.deleted.append((level, t.num))
            rec.added.append(
                AddedTable(
                    out_level, t.num, t.size, t.imin.copy(), t.imax.copy()
                )
            )
            self._commit(rec)
            return
        var streams = List[TableStream]()
        if level == 0:
            for t in inputs0:
                streams.append(TableStream([t.copy()]))
        else:
            streams.append(TableStream(inputs0.copy()))
        if len(inputs1) > 0:
            streams.append(TableStream(inputs1.copy()))
        var m = MergedStream(None, streams^)
        m.first()
        self._merge_into(m, out_level, rec)
        for t in inputs0:
            rec.deleted.append((level, t.num))
        for t in inputs1:
            rec.deleted.append((out_level, t.num))
        self._commit(rec)
        for t in inputs0:
            remove(t.path)
        for t in inputs1:
            remove(t.path)

    def _merge_into(
        mut self, mut m: MergedStream, out_level: Int, mut rec: SessionRecord
    ) raises:
        # Writes the newest version of each user key, dropping deletion
        # markers no deeper level needs, into tables of out_level.
        var w: Optional[TableWriter] = None
        var last = List[UInt8]()
        var has_last = False
        while m.valid():
            var uk = ukey(Span(m.key))
            if has_last and compare_bytes(uk, Span(last)) == 0:
                m.next()
                continue
            last = List[UInt8](uk)
            has_last = True
            if key_type(
                Span(m.key)
            ) == KEY_TYPE_DEL and self._version.base_level_for_key(
                out_level, uk
            ):
                m.next()
                continue
            if not w:
                w = TableWriter(
                    self._opts.block_size,
                    self._opts.block_restart_interval,
                    self._opts.compression,
                    self._opts.filter_bits_per_key,
                )
            w.value().append(Span(m.key), Span(m.value))
            if w.value().bytes_len() >= self._opts.compaction_table_size:
                var num = self._alloc()
                rec.added.append(
                    _write_table(self._dir, w.take(), num, out_level)
                )
            m.next()
        if w:
            var num = self._alloc()
            rec.added.append(_write_table(self._dir, w.take(), num, out_level))


def _apply_batch_record(
    rec: Span[UInt8, _], seq: UInt64, mut mem: MemDB
) raises -> UInt64:
    # Go decodeBatchToMem; returns the new last sequence number.
    var hdr = decode_batch_header(rec)
    var bseq = hdr[0]
    var n = hdr[1]
    if bseq < seq:
        raise Error("leveldb: batch corrupted: invalid sequence number")
    var data = rec[BATCH_HEADER_LEN:]
    var records = decode_batch(data)
    if len(records) != n:
        raise Error(
            t"leveldb: batch corrupted: invalid records length: {n} vs"
            t" {len(records)}"
        )
    var ik = List[UInt8]()
    for i in range(len(records)):
        ref r = records[i]
        ik.clear()
        make_internal_key(
            ik,
            data[r.key_pos : r.key_pos + r.key_len],
            bseq + UInt64(i),
            r.key_type,
        )
        mem.put(Span(ik), data[r.value_pos : r.value_pos + r.value_len])
    if n == 0:
        return max(seq, bseq)
    return bseq + UInt64(n) - 1


def _write_table(
    dir: String, var w: TableWriter, num: Int, level: Int
) raises -> AddedTable:
    var imin = w.first_key()
    var imax = w.last_key()
    var data = w.finish()
    write_file(
        join(dir, file_name(FileDesc(TYPE_TABLE, num))), Span(data), sync=True
    )
    return AddedTable(level, num, len(data), imin^, imax^)


def _flush_memdb(
    dir: String, mem: MemDB, num: Int, opts: Options
) raises -> Optional[AddedTable]:
    # Go session.flushMemdb: the newest version of each key goes to level 0.
    var w = TableWriter(
        opts.block_size,
        opts.block_restart_interval,
        opts.compression,
        opts.filter_bits_per_key,
    )
    var node = mem.first()
    var last = List[UInt8]()
    var has_last = False
    while node != 0:
        var k = mem.key_at(node)
        var uk = ukey(k)
        if not (has_last and compare_bytes(uk, Span(last)) == 0):
            w.append(k, mem.value_at(node))
            last = List[UInt8](uk)
            has_last = True
        node = mem.next(node)
    if w.entries() == 0:
        return None
    return _write_table(dir, w^, num, 0)
