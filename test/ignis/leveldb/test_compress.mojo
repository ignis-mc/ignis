from ignis.leveldb.compress import (
    FLATE_COMPRESSION,
    NO_COMPRESSION,
    SNAPPY_COMPRESSION,
    ZLIB_COMPRESSION,
    adler32,
    compress,
    decompress,
)
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def _sample() -> List[UInt8]:
    var out = List[UInt8]()
    for i in range(20000):
        out.append(UInt8((i * 7 + i // 100) & 0xFF))
    return out^


def test_adler32() raises:
    assert_equal(adler32("Wikipedia".as_bytes()), 0x11E60398)
    assert_equal(adler32(List[UInt8]()), 1)


def test_round_trips() raises:
    var data = _sample()
    for kind in [
        NO_COMPRESSION,
        SNAPPY_COMPRESSION,
        ZLIB_COMPRESSION,
        FLATE_COMPRESSION,
    ]:
        var c = compress(data, kind)
        if kind != NO_COMPRESSION:
            assert_true(len(c) < len(data))
        assert_equal(decompress(c, kind), data)


def test_zlib_known_stream() raises:
    # Python: zlib.compress(b"hello hello hello")
    var z: List[UInt8] = [
        0x78,
        0x9C,
        0xCB,
        0x48,
        0xCD,
        0xC9,
        0xC9,
        0x57,
        0xC8,
        0x40,
        0x90,
        0x00,
        0x3A,
        0x2E,
        0x06,
        0x7D,
    ]
    assert_equal(
        decompress(z, ZLIB_COMPRESSION),
        List[UInt8]("hello hello hello".as_bytes()),
    )
    z[len(z) - 1] ^= 1
    with assert_raises(contains="checksum"):
        _ = decompress(z, ZLIB_COMPRESSION)


def test_unknown_type() raises:
    with assert_raises(contains="unknown compression"):
        _ = decompress([UInt8(1)], 3)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
