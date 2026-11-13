from ignis.block.bedrock import Bedrock
from ignis.block.register import vanilla_block_registry
from ignis.world.biome.plains import Plains
from ignis.world.chunk.encode import encode
from ignis.world.chunk.encoding import NetworkEncoding
from ignis.world.dimension import NETHER, OVERWORLD
from ignis.world.generator import Generator
from ignis.world.generator.flat import Flat
from ignis.block.cube.pos import Pos
from nethernet.wire import hex_encode
from std.testing import TestSuite, assert_equal
from support.world_vectors import flat_chunk, flat_layers, load_vectors


def test_blocks_match_dragonfly_and_biomes_fill_the_range() raises:
    var br = vanilla_block_registry()
    var v = load_vectors()
    var c = flat_chunk(br)
    var d = encode(c, NetworkEncoding())
    # Blocks are Dragonfly's; biomes are Dragonfly's plus y 256-319.
    for i in range(24):
        var key = String(t"flat.sub.0{i}") if i < 10 else String(
            t"flat.sub.{i}"
        )
        assert_equal(hex_encode(Span(d.sub_chunks[i])), v[key])
    assert_equal(hex_encode(Span(d.biomes)), v["flat_fixed.biomes"])
    assert_equal(c.biome(0, 319, 0), 1)
    assert_equal(c.block(0, -64, 0, 0), br.block_runtime_id(Bedrock()))
    assert_equal(c.block(0, -60, 0, 0), br.air())


def test_default_spawn() raises:
    var br = vanilla_block_registry()
    var f = Flat(Plains(), flat_layers(br))
    assert_equal(f.default_spawn(OVERWORLD), Pos(0, -59, 0))
    assert_equal(f.default_spawn(NETHER), Pos(0, 5, 0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
