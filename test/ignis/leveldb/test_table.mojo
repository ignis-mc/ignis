from ignis.internal.fs import join, read_file, write_file
from ignis.leveldb.compress import (
    FLATE_COMPRESSION,
    NO_COMPRESSION,
    SNAPPY_COMPRESSION,
)
from ignis.leveldb.key import (
    KEY_MAX_SEQ,
    KEY_TYPE_DEL,
    KEY_TYPE_VAL,
    internal_key,
    key_type,
)
from ignis.leveldb.table import BlockIter, Table, TableWriter, read_footer
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.tempdir import remove_all, temp_dir


def _pad5(n: Int) -> String:
    var s = String(n)
    while s.byte_length() < 5:
        s = "0" + s
    return s^


def _entries() -> Tuple[List[List[UInt8]], List[List[UInt8]]]:
    # interop/mcdb/ldb_fixtures.go tableEntries.
    var keys = List[List[UInt8]]()
    var values = List[List[UInt8]]()
    var seq = UInt64(1000)
    for i in range(600):
        var u = String("key-", _pad5(i * 3), "-")
        for _ in range(i % 13):
            u += "x"
        if i % 7 == 0:
            keys.append(internal_key(u.as_bytes(), seq, KEY_TYPE_DEL))
            values.append(List[UInt8]())
            seq -= 1
        if i % 10 == 0:
            keys.append(internal_key(u.as_bytes(), seq, KEY_TYPE_VAL))
            values.append(List[UInt8](String("new-", i).as_bytes()))
            seq -= 1
        var v = List[UInt8]()
        for j in range(i % 97):
            v.append(UInt8((i + j * j) & 0xFF))
        keys.append(internal_key(u.as_bytes(), seq, KEY_TYPE_VAL))
        values.append(v^)
        seq -= 1
    return (keys^, values^)


def _build(compression: UInt8, bits: Int) raises -> List[UInt8]:
    var e = _entries()
    ref keys = e[0]
    ref values = e[1]
    var w = TableWriter(1024, 16, compression, bits)
    for i in range(len(keys)):
        w.append(keys[i], values[i])
    return w.finish()


def test_uncompressed_table_matches_goleveldb() raises:
    var got = _build(NO_COMPRESSION, 0)
    var want = read_file("test/data/leveldb/table-none.ldb")
    assert_equal(len(got), len(want))
    assert_true(got == want)


def test_snappy_table_matches_goleveldb() raises:
    var got = _build(SNAPPY_COMPRESSION, 0)
    var want = read_file("test/data/leveldb/table-snappy.ldb")
    assert_equal(len(got), len(want))
    assert_true(got == want)


def test_bloom_table_matches_goleveldb_up_to_the_metaindex() raises:
    # Data and filter blocks are identical; the metaindex differs only in
    # the policy name (goleveldb "leveldb.BuiltinBloomFilter", C++ and
    # Mojang "leveldb.BuiltinBloomFilter2").
    var got = _build(NO_COMPRESSION, 10)
    var want = read_file("test/data/leveldb/table-none-bloom.ldb")
    var hw = read_footer(Span(want)[len(want) - 48 :])
    var hg = read_footer(Span(got)[len(got) - 48 :])
    assert_equal(hw[0].offset, hg[0].offset)
    assert_true(
        List[UInt8](Span(got)[: hg[0].offset])
        == List[UInt8](Span(want)[: hw[0].offset])
    )
    assert_equal(len(got), len(want) + 1)


def _check_table(path: String, has_filter: Bool) raises:
    var e = _entries()
    var size = len(read_file(path))
    var t = Table(1, size, path, e[0][0].copy(), e[0][len(e[0]) - 1].copy())
    assert_equal(Bool(t._filter), has_filter)
    # Full scan in order.
    var n = 0
    for b in range(t.blocks()):
        var it = t.read_block(b)
        it.first()
        while it.valid():
            assert_true(List[UInt8](it.key()) == e[0][n])
            assert_true(List[UInt8](it.value()) == e[1][n])
            n += 1
            it.next()
    assert_equal(n, len(e[0]))
    # Point lookups find the newest version of each user key.
    for i in range(0, 600, 1):
        var u = String("key-", _pad5(i * 3), "-")
        for _ in range(i % 13):
            u += "x"
        var r = t.get(internal_key(u.as_bytes(), KEY_MAX_SEQ, KEY_TYPE_VAL))
        assert_true(Bool(r))
        if i % 7 == 0:
            assert_equal(key_type(r.value()[0]), KEY_TYPE_DEL)
        elif i % 10 == 0:
            assert_equal(
                r.value()[1], List[UInt8](String("new-", i).as_bytes())
            )
        var missing = t.get(
            internal_key(
                String("key-", _pad5(i * 3 + 1)).as_bytes(),
                KEY_MAX_SEQ,
                KEY_TYPE_VAL,
            )
        )
        assert_false(Bool(missing))


def test_reads_every_goleveldb_table() raises:
    _check_table("test/data/leveldb/table-none.ldb", False)
    _check_table("test/data/leveldb/table-none-bloom.ldb", True)
    _check_table("test/data/leveldb/table-snappy.ldb", False)
    _check_table("test/data/leveldb/table-flate-bloom.ldb", True)


def test_reads_own_flate_and_zlib_tables() raises:
    var dir = temp_dir("table")
    for c in [FLATE_COMPRESSION, UInt8(2)]:
        var p = join(dir, String("t", c, ".ldb"))
        write_file(p, _build(c, 10), sync=False)
        _check_table(p, True)
    remove_all(dir)


def test_block_iter_seek() raises:
    var e = _entries()
    var t = Table(
        1, 0, "test/data/leveldb/table-none.ldb", e[0][0].copy(), e[0][0].copy()
    )
    var it = t.read_block(3)
    it.first()
    var first = List[UInt8](it.key())
    it.next()
    it.next()
    var third = List[UInt8](it.key())
    it.seek(first)
    assert_true(List[UInt8](it.key()) == first)
    it.seek(third)
    assert_true(List[UInt8](it.key()) == third)
    it.seek(internal_key("zzz".as_bytes(), 1, KEY_TYPE_VAL))
    assert_false(it.valid())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
