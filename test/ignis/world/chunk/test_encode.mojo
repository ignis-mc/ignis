from ignis.block.register import vanilla_block_registry
from ignis.world.chunk.chunk import Chunk
from ignis.world.chunk.encode import (
    SUB_CHUNK_VERSION,
    encode,
    encode_biomes,
    encode_sub_chunk,
)
from ignis.world.chunk.encoding import NetworkEncoding
from nethernet.wire import hex_encode
from std.collections import Dict
from std.testing import TestSuite, assert_equal
from support.world_vectors import (
    biome_chunk,
    flat_chunk,
    flat_chunk_dragonfly,
    load_vectors,
    mixed_chunk,
    new_chunk,
    simple_chunk,
    widths,
)


def _sub_key(name: String, i: Int) -> String:
    if i < 10:
        return String(t"{name}.sub.0{i}")
    return String(t"{name}.sub.{i}")


def _check_chunk(v: Dict[String, String], name: String, c: Chunk) raises:
    var d = encode(c, NetworkEncoding())
    assert_equal(len(d.sub_chunks), 24)
    for i in range(len(d.sub_chunks)):
        assert_equal(
            hex_encode(Span(d.sub_chunks[i])),
            v[_sub_key(name, i)],
            _sub_key(name, i),
        )
    assert_equal(hex_encode(Span(d.biomes)), v[name + ".biomes"], name)


def test_empty_chunk() raises:
    var br = vanilla_block_registry()
    _check_chunk(load_vectors(), "empty", new_chunk(br))


def test_simple_chunk() raises:
    var br = vanilla_block_registry()
    _check_chunk(load_vectors(), "simple", simple_chunk(br))


def test_biome_chunk() raises:
    var br = vanilla_block_registry()
    _check_chunk(load_vectors(), "biomes", biome_chunk(br))


def test_flat_chunk_as_dragonfly_builds_it() raises:
    var br = vanilla_block_registry()
    _check_chunk(load_vectors(), "flat", flat_chunk_dragonfly(br))


def test_mixed_palettes_of_every_width() raises:
    var br = vanilla_block_registry()
    var v = load_vectors()
    var c = mixed_chunk(br)
    var ws = widths()
    for i in range(len(ws)):
        assert_equal(Int(c.sub()[i].layers()[0].bits_per_index()), ws[i])
        var sub = encode_sub_chunk(c, NetworkEncoding(), i)
        assert_equal(hex_encode(Span(sub)), v[_sub_key("mixed", i)])
    # The last sub-chunk also has a water layer.
    assert_equal(len(c.sub()[len(ws) - 1].layers()), 2)


def test_sub_chunk_header() raises:
    var br = vanilla_block_registry()
    var c = new_chunk(br)
    c.set_block(0, 0, 0, 0, 1)
    var sub = encode_sub_chunk(c, NetworkEncoding(), 4)
    assert_equal(sub[0], SUB_CHUNK_VERSION)
    assert_equal(sub[1], 1)
    # The absolute sub-chunk Y: index 4 of a chunk starting at -64.
    assert_equal(sub[2], 0)
    assert_equal(encode_sub_chunk(c, NetworkEncoding(), 0)[2], 0xFC)
    # 24 uniform storages of biome 0: header 0x01, palette value 0.
    assert_equal(len(encode_biomes(c, NetworkEncoding())), 24 * 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
