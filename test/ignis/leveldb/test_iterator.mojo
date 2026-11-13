from ignis.internal.fs import join, write_file
from ignis.leveldb.compress import NO_COMPRESSION
from ignis.leveldb.iterator import (
    Iterator,
    MemStream,
    MergedStream,
    TableStream,
)
from ignis.leveldb.key import KEY_TYPE_DEL, KEY_TYPE_VAL, internal_key
from ignis.leveldb.memdb import MemDB
from ignis.leveldb.table import Table, TableWriter
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.tempdir import remove_all, temp_dir


def _table(
    dir: String, num: Int, keys: List[String], seq: UInt64, kt: UInt8
) raises -> Table:
    var w = TableWriter(64, 2, NO_COMPRESSION, 0)
    for k in keys:
        w.append(
            internal_key(k.as_bytes(), seq, kt), String("v", seq).as_bytes()
        )
    var imin = w.first_key()
    var imax = w.last_key()
    var data = w.finish()
    var p = join(dir, String(num, ".ldb"))
    write_file(p, data, sync=False)
    return Table(num, len(data), p, imin^, imax^)


def test_merge_newest_wins_and_deletes_hide() raises:
    var dir = temp_dir("iter")
    var old = _table(dir, 1, ["a", "b", "c", "d", "e"], 1, KEY_TYPE_VAL)
    var t2 = _table(dir, 2, ["f", "g"], 2, KEY_TYPE_VAL)
    var dels = _table(dir, 3, ["b", "f"], 5, KEY_TYPE_DEL)
    var mem = MemDB()
    mem.put(internal_key("c".as_bytes(), 9, KEY_TYPE_VAL), "mem".as_bytes())
    mem.put(internal_key("h".as_bytes(), 8, KEY_TYPE_VAL), "h".as_bytes())
    var streams = List[TableStream]()
    streams.append(TableStream([old^, t2^]))
    streams.append(TableStream([dels^]))
    var it = Iterator(MergedStream(MemStream(mem^), streams^))
    var keys = List[String]()
    var values = List[String]()
    while it.next():
        keys.append(String(from_utf8=it.key()))
        values.append(String(from_utf8=it.value()))
    assert_equal(keys, ["a", "c", "d", "e", "g", "h"])
    assert_equal(values[1], "mem")
    assert_equal(values[4], "v2")
    remove_all(dir)


def test_table_stream_seek_across_tables() raises:
    var dir = temp_dir("iter")
    var t1 = _table(
        dir, 1, ["a1", "a2", "a3", "a4", "a5", "a6"], 1, KEY_TYPE_VAL
    )
    var t2 = _table(dir, 2, ["b1", "b2"], 1, KEY_TYPE_VAL)
    var s = TableStream([t1^, t2^])
    s.seek(internal_key("a7".as_bytes(), 100, KEY_TYPE_VAL))
    assert_true(s.valid())
    assert_equal(String(from_utf8=s.key()[:2]), "b1")
    s.next()
    s.next()
    assert_false(s.valid())
    s.first()
    var n = 0
    while s.valid():
        n += 1
        s.next()
    assert_equal(n, 8)
    remove_all(dir)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
