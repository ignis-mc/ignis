from ignis.leveldb.util import (
    compare_bytes,
    get_u32,
    get_u64,
    hash,
    hash_signed_tail,
    masked_crc,
    put_u32,
    put_u64,
    put_uvarint,
    read_uvarint,
)
from nethernet.crypto.crc import crc32c
from std.testing import TestSuite, assert_equal, assert_raises


def test_hash_goleveldb_vectors() raises:
    # goleveldb util/hash_test.go (also C++ LevelDB util/hash_test.cc).
    assert_equal(hash(List[UInt8](), 0xBC9F1D34), 0xBC9F1D34)
    assert_equal(hash([UInt8(0x62)], 0xBC9F1D34), 0xEF1345C4)
    assert_equal(hash([UInt8(0xC3), 0x97], 0xBC9F1D34), 0x5B663814)
    assert_equal(hash([UInt8(0xE2), 0x99, 0xA5], 0xBC9F1D34), 0x323C078F)
    assert_equal(hash([UInt8(0xE1), 0x80, 0xB9, 0x32], 0xBC9F1D34), 0xED21633A)
    var long: List[UInt8] = [
        0x01,
        0xC0,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x14,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x04,
        0x00,
        0x00,
        0x00,
        0x00,
        0x14,
        0x00,
        0x00,
        0x00,
        0x18,
        0x28,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x02,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
    ]
    assert_equal(hash(long, 0x12345678), 0xF333DABB)


def test_signed_tail_variant() raises:
    # Equal when every tail byte is below 0x80, different otherwise.
    assert_equal(hash_signed_tail([UInt8(0x62)], 1), hash([UInt8(0x62)], 1))
    assert_equal(
        hash_signed_tail([UInt8(1), 2, 3, 4, 0x80], 1)
        == hash([UInt8(1), 2, 3, 4, 0x80], 1),
        False,
    )


def test_crc() raises:
    assert_equal(crc32c("123456789".as_bytes()), 0xE3069283)
    var c = crc32c("123456789".as_bytes())
    assert_equal(
        masked_crc("123456789".as_bytes()), ((c >> 15) | (c << 17)) + 0xA282EAD8
    )


def test_varints_and_fixed() raises:
    var out = List[UInt8]()
    put_uvarint(out, 0)
    put_uvarint(out, 127)
    put_uvarint(out, 300)
    put_uvarint(out, UInt64.MAX)
    assert_equal(out[2], 0xAC)
    assert_equal(out[3], 0x02)
    var pos = 0
    assert_equal(read_uvarint(out, pos), 0)
    assert_equal(read_uvarint(out, pos), 127)
    assert_equal(read_uvarint(out, pos), 300)
    assert_equal(read_uvarint(out, pos), UInt64.MAX)
    assert_equal(pos, len(out))
    with assert_raises(contains="truncated"):
        var p = 0
        _ = read_uvarint([UInt8(0x80)], p)
    var f = List[UInt8]()
    put_u32(f, 0x01020304)
    put_u64(f, 0x0102030405060708)
    assert_equal(f[0], 4)
    assert_equal(get_u32(f, 0), 0x01020304)
    assert_equal(get_u64(f, 4), 0x0102030405060708)


def test_compare_bytes() raises:
    assert_equal(compare_bytes("a".as_bytes(), "b".as_bytes()), -1)
    assert_equal(compare_bytes("ab".as_bytes(), "a".as_bytes()), 1)
    assert_equal(compare_bytes("ab".as_bytes(), "ab".as_bytes()), 0)
    assert_equal(compare_bytes([UInt8(0xFF)], [UInt8(0x01), 0x01]), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
