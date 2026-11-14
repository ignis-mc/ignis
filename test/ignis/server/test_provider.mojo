from std.memory import ArcPointer

from ignis.block.register import vanilla_block_registry
from ignis.internal.fs import join
from ignis.server.provider import WorldProvider
from ignis.world.chunk.chunk import Chunk
from ignis.world.chunk.column import Column
from ignis.world.dimension import OVERWORLD
from ignis.world.position import ChunkPos
from std.testing import TestSuite, assert_false, assert_true
from support.tempdir import remove_all, temp_dir


def test_nop_stores_nothing() raises:
    var p = WorldProvider()
    assert_false(p.on_disk())
    assert_false(Bool(p.settings()))
    var br = vanilla_block_registry("resources/block_states.nbt")
    p.store_column(
        ChunkPos(0, 0),
        OVERWORLD,
        Column(Chunk(br.air_runtime_id(), OVERWORLD.range())),
    )
    assert_false(Bool(p.load_column(ChunkPos(0, 0), OVERWORLD)))


def test_disk_round_trip() raises:
    var dir = temp_dir("world-provider")
    var br = ArcPointer(vanilla_block_registry("resources/block_states.nbt"))
    var p = WorldProvider.open(join(dir, "w"), br)
    assert_true(p.on_disk())
    assert_true(Bool(p.settings()))
    p.store_column(
        ChunkPos(2, -3),
        OVERWORLD,
        Column(Chunk(br[].air_runtime_id(), OVERWORLD.range())),
    )
    assert_true(Bool(p.load_column(ChunkPos(2, -3), OVERWORLD)))
    p.close()
    _ = p^
    remove_all(dir)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
