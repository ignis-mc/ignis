from ignis.block.cube.pos import Pos
from ignis.block.register import vanilla_block_registry
from ignis.world.chunk.chunk import Chunk
from ignis.world.dimension import OVERWORLD
from ignis.world.generator import Generator, NopGenerator
from ignis.world.position import ChunkPos
from std.testing import TestSuite, assert_equal


def test_nop_generator() raises:
    var br = vanilla_block_registry()
    var c = Chunk(br, OVERWORLD.range())
    NopGenerator().generate_chunk(ChunkPos(0, 0), c)
    assert_equal(c.highest_filled_sub_chunk(), 0)
    assert_equal(NopGenerator().default_spawn(OVERWORLD), Pos(0, 0, 0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
