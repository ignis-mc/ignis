from ignis.internal.fs import read_file
from ignis.leveldb.journal import BLOCK_SIZE, JournalReader, JournalWriter
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _sizes() -> List[Int]:
    # interop/mcdb/ldb_fixtures.go journalRecordSizes.
    return [
        0,
        1,
        100,
        32768 - 7 - 107 - 7 - 7,
        0,
        40000,
        32768 * 2,
        32768 - 7 - 5,
        10,
    ]


def _record(n: Int) -> List[UInt8]:
    var r = List[UInt8](capacity=n)
    for i in range(n):
        r.append(UInt8((n + i) & 0xFF))
    return r^


def test_writer_matches_goleveldb() raises:
    var w = JournalWriter()
    var out = List[UInt8]()
    for n in _sizes():
        w.append(_record(n), out)
    var want = read_file("test/data/leveldb/journal.log")
    assert_equal(len(out), len(want))
    assert_true(out == want)


def test_reader_reads_goleveldb() raises:
    var r = JournalReader(read_file("test/data/leveldb/journal.log"))
    for n in _sizes():
        var rec = r.next()
        assert_true(Bool(rec))
        assert_equal(rec.value(), _record(n))
    assert_false(Bool(r.next()))
    assert_equal(r.dropped, 0)


def test_corruption_drops_block_and_torn_tail() raises:
    var w = JournalWriter()
    var out = List[UInt8]()
    for i in range(5):
        w.append(_record(10000 + i), out)
    # Corrupt one byte of the first record (block 0): goleveldb drops the
    # rest of block 0, which holds records 0-2 and the start of record 3,
    # whose remaining chunk is then an orphan.
    out[100] ^= 0xFF
    var r = JournalReader(out.copy())
    var rec = r.next()
    assert_equal(len(rec.value()), 10004)
    assert_false(Bool(r.next()))
    assert_true(r.dropped > 0)
    # A torn final record is dropped, earlier ones survive.
    var w2 = JournalWriter()
    var out2 = List[UInt8]()
    w2.append(_record(50), out2)
    w2.append(_record(60), out2)
    out2.resize(len(out2) - 3, 0)
    var r2 = JournalReader(out2^)
    assert_equal(len(r2.next().value()), 50)
    assert_false(Bool(r2.next()))


def test_continue_offset() raises:
    var w = JournalWriter(BLOCK_SIZE - 3)
    var out = List[UInt8]()
    w.append(_record(5), out)
    # Three bytes of zero padding, then the record in the next block.
    assert_equal(out[0], 0)
    assert_equal(out[2], 0)
    assert_equal(len(out), 3 + 7 + 5)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
