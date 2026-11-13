from ignis.block.register import vanilla_block_registry
from ignis.world.chunk.decode import decode_paletted_storage, network_decode
from ignis.world.chunk.encode import encode
from ignis.world.chunk.encoding import NetworkEncoding
from ignis.world.dimension import OVERWORLD
from nethernet.wire import hex_decode, hex_encode
from std.collections import Dict
from std.testing import TestSuite, assert_equal, assert_raises, assert_true
from support.world_vectors import load_vectors, mixed_chunk


def _payload(v: Dict[String, String], name: String) raises -> List[UInt8]:
    var out = List[UInt8]()
    for i in range(24):
        var key = String(t"{name}.sub.0{i}") if i < 10 else String(
            t"{name}.sub.{i}"
        )
        out.extend(hex_decode(v[key]))
    out.extend(hex_decode(v[name + ".biomes"]))
    return out^


def test_dragonfly_chunks_round_trip() raises:
    var br = vanilla_block_registry()
    var v = load_vectors()
    for name in ["empty", "simple", "flat", "flat_fixed", "biomes"]:
        var data = _payload(v, name)
        var c = network_decode(br, Span(data), 24, OVERWORLD.range())
        var d = encode(c, NetworkEncoding())
        var again = List[UInt8]()
        for ref s in d.sub_chunks:
            again.extend(Span(s))
        again.extend(Span(d.biomes))
        assert_equal(hex_encode(Span(again)), hex_encode(Span(data)), name)


def test_mixed_round_trip() raises:
    var br = vanilla_block_registry()
    var c = mixed_chunk(br)
    var d = encode(c, NetworkEncoding())
    var data = List[UInt8]()
    for ref s in d.sub_chunks:
        data.extend(Span(s))
    data.extend(Span(d.biomes))
    var back = network_decode(br, Span(data), 24, OVERWORLD.range())
    assert_true(back.equals(c))
    for x in range(16):
        for z in range(16):
            assert_equal(
                back.block(UInt8(x), 0, UInt8(z), 0),
                c.block(UInt8(x), 0, UInt8(z), 0),
            )


def test_rejects_bad_counts() raises:
    var br = vanilla_block_registry()
    var empty = List[UInt8]()
    with assert_raises(contains="sub-chunk count"):
        _ = network_decode(br, Span(empty), 25, OVERWORLD.range())
    with assert_raises(contains="end of data"):
        _ = network_decode(br, Span(empty), 1, OVERWORLD.range())


def test_rejects_undefined_sizes() raises:
    # Size 7 is accepted by Go and builds an inconsistent storage.
    var data: List[UInt8] = [7 << 1 | 1]
    data.extend(List[UInt8](length=4096, fill=0))
    var pos = 0
    with assert_raises(contains="size=7"):
        _ = decode_paletted_storage[NetworkEncoding](Span(data), pos)


def test_rejects_indices_past_the_palette() raises:
    # 1 bit per index, index 1 everywhere, but a palette of one value.
    var data: List[UInt8] = [1 << 1 | 1]
    data.extend(List[UInt8](length=512, fill=0xFF))
    data.append(2)  # varint32 1: one palette entry
    data.append(0)
    var pos = 0
    with assert_raises(contains="past the palette"):
        _ = decode_paletted_storage[NetworkEncoding](Span(data), pos)


def test_rejects_previous_as_first_biome() raises:
    var br = vanilla_block_registry()
    var data: List[UInt8] = [0xFF]
    with assert_raises(contains="first biome"):
        _ = network_decode(br, Span(data), 0, OVERWORLD.range())


def test_rejects_unknown_version() raises:
    var br = vanilla_block_registry()
    var data: List[UInt8] = [7]
    with assert_raises(contains="version 7"):
        _ = network_decode(br, Span(data), 1, OVERWORLD.range())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
