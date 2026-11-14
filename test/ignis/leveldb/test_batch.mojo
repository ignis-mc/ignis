from ignis.leveldb.batch import Batch, decode_batch, decode_batch_header
from ignis.leveldb.key import KEY_TYPE_DEL, KEY_TYPE_VAL
from std.testing import TestSuite, assert_equal, assert_raises


def test_record_layout() raises:
    var b = Batch()
    b.put("ab".as_bytes(), "xyz".as_bytes())
    b.delete("c".as_bytes())
    assert_equal(len(b), 2)
    assert_equal(b.internal_len(), 2 + 3 + 8 + 1 + 8)
    var rec = List[UInt8]()
    b.encode_record(0x0102, rec)
    # goleveldb batch.go: seq u64 LE, count u32 LE, then records.
    var want: List[UInt8] = [
        0x02,
        0x01,
        0,
        0,
        0,
        0,
        0,
        0,
        2,
        0,
        0,
        0,
        1,
        2,
        0x61,
        0x62,
        3,
        0x78,
        0x79,
        0x7A,
        0,
        1,
        0x63,
    ]
    assert_equal(rec, want)
    var hdr = decode_batch_header(rec)
    assert_equal(hdr[0], 0x0102)
    assert_equal(hdr[1], 2)
    var recs = decode_batch(Span(rec)[12:])
    assert_equal(len(recs), 2)
    assert_equal(recs[0].key_type, KEY_TYPE_VAL)
    assert_equal(recs[0].value_len, 3)
    assert_equal(recs[1].key_type, KEY_TYPE_DEL)
    b.reset()
    assert_equal(len(b), 0)


def test_corrupt() raises:
    with assert_raises(contains="invalid type"):
        _ = decode_batch([UInt8(7), 0])
    with assert_raises(contains="key length"):
        _ = decode_batch([UInt8(1), 5, 1])
    with assert_raises(contains="too short"):
        _ = decode_batch_header([UInt8(1)])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
