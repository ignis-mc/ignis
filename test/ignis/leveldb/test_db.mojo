from ignis.internal.fs import exists, join, list_dir, read_file
from ignis.leveldb.batch import Batch
from ignis.leveldb.db import DB
from ignis.leveldb.options import KIB, Options
from ignis.leveldb.storage import TYPE_TABLE, parse_file_name
from std.collections import Dict
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)
from support.ldb_workload import gen_batches, options
from support.tempdir import copy_dir, remove_all, temp_dir


def _b(s: StringSlice) -> List[UInt8]:
    return List[UInt8](s.as_bytes())


def _hex(b: Span[UInt8, _]) -> String:
    var s = String()
    comptime h = "0123456789abcdef"
    for c in b:
        s += String(h[byte=Int(c >> 4)])
        s += String(h[byte=Int(c & 15)])
    return s^


def _expected(
    seed: UInt64, n: Int, drop_last: Bool
) raises -> Dict[String, List[UInt8]]:
    # Replays the workload into a map keyed by hex user key.
    from ignis.leveldb.batch import decode_batch
    from ignis.leveldb.key import KEY_TYPE_DEL

    var m = Dict[String, List[UInt8]]()
    var batches = gen_batches(seed, n)
    var count = len(batches) - 1 if drop_last else len(batches)
    for i in range(count):
        var data = batches[i].data()
        for r in decode_batch(data):
            var k = _hex(data[r.key_pos : r.key_pos + r.key_len])
            if r.key_type == KEY_TYPE_DEL:
                _ = m.pop(k, List[UInt8]())
            else:
                m[k] = List[UInt8](
                    data[r.value_pos : r.value_pos + r.value_len]
                )
    return m^


def _check(db: DB, want: Dict[String, List[UInt8]]) raises:
    var it = db.new_iterator()
    var n = 0
    var prev = String()
    while it.next():
        var k = _hex(it.key())
        assert_true(n == 0 or prev < k)
        assert_true(k in want)
        assert_true(List[UInt8](it.value()) == want[k])
        prev = k
        n += 1
    assert_equal(n, len(want))


def test_put_get_delete_reopen() raises:
    var dir = temp_dir("ldb")
    var db = DB(dir)
    db.put(_b("a"), _b("1"))
    db.put(_b("b"), _b("2"))
    db.put(_b("a"), _b("3"))
    db.delete(_b("b"))
    assert_equal(db.get(_b("a")).value(), _b("3"))
    assert_false(db.has(_b("b")))
    _ = db^
    var db2 = DB(dir)
    assert_equal(db2.get(_b("a")).value(), _b("3"))
    assert_false(Bool(db2.get(_b("b"))))
    var it = db2.new_iterator()
    assert_true(it.next())
    assert_equal(List[UInt8](it.key()), _b("a"))
    assert_false(it.next())
    _ = db2^
    remove_all(dir)


def test_lock() raises:
    var dir = temp_dir("ldb")
    var db = DB(dir)
    with assert_raises(contains="lock"):
        _ = DB(dir)
    _ = db^
    _ = DB(dir)
    remove_all(dir)


def test_workload_flushes_compacts_and_reopens() raises:
    var dir = temp_dir("ldb")
    var want = _expected(3, 2500, False)
    var db = DB(dir, options())
    for b in gen_batches(3, 2500):
        db.write(b)
    _check(db, want)
    var levels_used = 0
    for l in db.version().levels:
        if len(l) > 0:
            levels_used += 1
    assert_true(levels_used >= 2)
    # Point lookups agree with the iterator.
    var it = db.new_iterator()
    while it.next():
        assert_true(db.get(it.key()).value() == List[UInt8](it.value()))
    _ = db^
    var db2 = DB(dir, options())
    _check(db2, want)
    # Only live tables remain on disk.
    var tables = 0
    for name in list_dir(dir):
        if case .Some(fd) = parse_file_name(name):
            if fd.type == TYPE_TABLE:
                tables += 1
                assert_true(db2.version().has_table(fd.num))
    assert_equal(tables, db2.version().table_count())
    _ = db2^
    remove_all(dir)


def test_unclean_stop_recovers_journal() raises:
    var dir = temp_dir("ldb")
    var copy = dir + "-copy"
    var db = DB(dir, options())
    for b in gen_batches(5, 800):
        db.write(b)
    # Copy the files while the database is still open: nothing was closed,
    # flushed or synced beyond what each write did.
    copy_dir(dir, copy)
    _ = db^
    _ = read_file(join(copy, "CURRENT"))
    var db2 = DB(copy, options())
    _check(db2, _expected(5, 800, False))
    _ = db2^
    remove_all(dir)
    remove_all(copy)


def test_reads_goleveldb_unclean_fixture() raises:
    # interop/mcdb: `go run . ldb-write <dir> 11 250 unclean`, so the last
    # batches live only in the journals.
    var dir = temp_dir("ldb")
    copy_dir("test/data/leveldb/goleveldb-unclean", dir)
    var db = DB(dir, options())
    _check(db, _expected(11, 250, False))
    _ = db^
    remove_all(dir)


def test_compact_all_drops_deleted_and_overwritten() raises:
    var dir = temp_dir("ldb")
    var o = Options()
    o.write_buffer = 4 * KIB
    var db = DB(dir, o^)
    for i in range(500):
        db.put(_b(String("k", i)), _b(String("v", i)))
    for i in range(500):
        if i % 2 == 0:
            db.delete(_b(String("k", i)))
        else:
            db.put(_b(String("k", i)), _b(String("w", i)))
    db.compact_all()
    assert_equal(len(db.version().levels[0]), 0)
    var it = db.new_iterator()
    var n = 0
    while it.next():
        n += 1
        assert_true(String(from_utf8=it.value()).startswith("w"))
    assert_equal(n, 250)
    # Deleted keys are gone from the tables, not just hidden.
    var entries = 0
    for l in db.version().levels:
        for t in l:
            for b in range(t.blocks()):
                var bi = t.read_block(b)
                bi.first()
                while bi.valid():
                    entries += 1
                    bi.next()
    assert_equal(entries, 250)
    _ = db^
    remove_all(dir)


def test_overwrites_stay_bounded() raises:
    # A world saves the same chunks over and over: 20 MiB of writes over 50
    # keys must not leave 20 MiB of tables behind.
    var dir = temp_dir("ldb")
    var o = Options()
    o.write_buffer = 64 * KIB
    o.compaction_table_size = 32 * KIB
    o.compaction_total_size = 128 * KIB
    var db = DB(dir, o^)
    var value = List[UInt8](capacity=10000)
    for round in range(40):
        for k in range(50):
            value.clear()
            for i in range(10000):
                value.append(UInt8((i * 31 + k * 7 + round) & 0xFF))
            db.put(_b(String("chunk-", k)), value)
    var total = 0
    var files = 0
    for name in list_dir(dir):
        if name.endswith(".ldb"):
            total += len(read_file(join(dir, name)))
            files += 1
    # 50 live values of 10 KB, compressed; allow for one memtable's worth of
    # level-0 tables and not-yet-merged older versions.
    assert_true(total < 1500 * 1000, String("tables hold ", total, " bytes"))
    assert_true(files < 40, String(files, " tables"))
    for k in range(50):
        var v = db.get(_b(String("chunk-", k))).value().copy()
        assert_equal(v[0], UInt8((k * 7 + 39) & 0xFF))
    _ = db^
    remove_all(dir)


def test_iterator_seek_and_batch() raises:
    var dir = temp_dir("ldb")
    var db = DB(dir)
    var b = Batch()
    for i in range(10):
        b.put(_b(String("key", i)), _b(String(i)))
    b.delete(_b("key3"))
    db.write(b)
    db.flush()
    db.put(_b("key5"), _b("five"))
    var it = db.new_iterator()
    assert_true(it.seek(_b("key25")))
    assert_equal(List[UInt8](it.key()), _b("key4"))
    assert_true(it.next())
    assert_equal(List[UInt8](it.value()), _b("five"))
    assert_true(it.seek(_b("key3")))
    assert_equal(List[UInt8](it.key()), _b("key4"))
    assert_false(it.seek(_b("zzz")))
    assert_equal(db.get(_b("key5")).value(), _b("five"))
    _ = db^
    remove_all(dir)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
