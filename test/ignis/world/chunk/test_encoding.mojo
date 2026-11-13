from ignis.world.chunk.encoding import (
    NetworkEncoding,
    put_varint32,
    read_varint32,
)
from ignis.world.chunk.palette import Palette
from nethernet.wire import hex_encode
from std.testing import TestSuite, assert_equal, assert_raises


def test_varint32() raises:
    var buf = List[UInt8]()
    for v in [Int32(0), -1, 1, 63, -64, 64, 300, Int32.MAX, Int32.MIN]:
        buf.clear()
        put_varint32(buf, v)
        var pos = 0
        assert_equal(read_varint32(Span(buf), pos), v)
        assert_equal(pos, len(buf))
    buf.clear()
    put_varint32(buf, 300)
    assert_equal(hex_encode(Span(buf)), "d804")
    var bad: List[UInt8] = [0x80, 0x80, 0x80, 0x80, 0x80, 0x00]
    var pos = 0
    with assert_raises(contains="5 bytes"):
        _ = read_varint32(Span(bad), pos)


def test_network_palette() raises:
    var buf = List[UInt8]()
    NetworkEncoding.encode_palette(buf, Palette(0, [5]))
    assert_equal(hex_encode(Span(buf)), "0a")
    buf.clear()
    NetworkEncoding.encode_palette(buf, Palette(1, [5, 300]))
    assert_equal(hex_encode(Span(buf)), "040ad804")
    var pos = 0
    var p = NetworkEncoding.decode_palette(Span(buf), pos, 1)
    assert_equal(p.values(), [5, 300])
    var zero: List[UInt8] = [0]
    pos = 0
    with assert_raises(contains="count 0"):
        _ = NetworkEncoding.decode_palette(Span(zero), pos, 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
