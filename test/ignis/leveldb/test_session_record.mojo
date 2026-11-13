from ignis.leveldb.session_record import AddedTable, CompPtr, SessionRecord
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def test_round_trip_and_layout() raises:
    var r = SessionRecord()
    r.comparer = String("leveldb.BytewiseComparator")
    r.journal_num = 5
    r.next_file_num = 300
    r.seq_num = UInt64(1) << 40
    r.comp_ptrs.append(CompPtr(1, [UInt8(1), 2, 3]))
    r.deleted.append((2, 17))
    r.added.append(AddedTable(0, 7, 4096, [UInt8(0xA)], [UInt8(0xB), 0xC]))
    var out = List[UInt8]()
    r.encode(out)
    # Tag 1, length 26, the name; tag 2 journal 5; tag 3 next file 300.
    assert_equal(out[0], 1)
    assert_equal(out[1], 26)
    assert_equal(out[28], 2)
    assert_equal(out[29], 5)
    assert_equal(out[30], 3)
    assert_equal(out[31], 0xAC)
    assert_equal(out[32], 0x02)
    var d = SessionRecord.decode(out)
    assert_equal(d.comparer.value(), "leveldb.BytewiseComparator")
    assert_equal(d.journal_num.value(), 5)
    assert_equal(d.next_file_num.value(), 300)
    assert_equal(d.seq_num.value(), UInt64(1) << 40)
    assert_equal(d.comp_ptrs[0].ikey, [UInt8(1), 2, 3])
    assert_equal(d.deleted[0][1], 17)
    assert_equal(d.added[0].size, 4096)
    assert_equal(d.added[0].imax, [UInt8(0xB), 0xC])
    assert_true(not d.prev_journal_num)


def test_prev_journal_and_errors() raises:
    var d = SessionRecord.decode([UInt8(9), 4])
    assert_equal(d.prev_journal_num.value(), 4)
    with assert_raises(contains="unknown field"):
        _ = SessionRecord.decode([UInt8(8), 1])
    with assert_raises(contains="short read"):
        _ = SessionRecord.decode([UInt8(1), 10, 0x61])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
