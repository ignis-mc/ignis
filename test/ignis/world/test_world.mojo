from ignis.block.bedrock import Bedrock
from ignis.block.dirt import Dirt
from ignis.block.grass import Grass
from ignis.block.cube.pos import Pos
from ignis.block.register import vanilla_block_registry
from ignis.world.biome.plains import Plains
from ignis.world.generator.flat import Flat
from ignis.world.position import ChunkPos
from ignis.world.world import (
    Settings,
    World,
    chunk_key,
    chunk_pos_from_block,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def _world() raises -> World[Flat]:
    var br = vanilla_block_registry()
    var layers: List[UInt32] = [
        br.block_runtime_id(Grass()),
        br.block_runtime_id(Dirt()),
        br.block_runtime_id(Dirt()),
        br.block_runtime_id(Bedrock()),
    ]
    return World(br^, Flat(Plains(), layers^), Settings())


def test_spawn_from_generator() raises:
    var w = _world()
    assert_true(w.spawn() == Pos(0, -59, 0))


def test_chunk_generated_once() raises:
    var w = _world()
    var pos = ChunkPos(2, -3)
    assert_false(w.chunk_loaded(pos))
    var grass = w.block_registry().block_runtime_id(Grass())
    assert_equal(w.chunk(pos).block(0, -61, 0, 0), grass)
    assert_true(w.chunk_loaded(pos))
    var air = w.block_registry().air()
    w.chunk(pos).set_block(1, -61, 1, 0, air)
    assert_equal(w.chunk(pos).block(1, -61, 1, 0), air)


def test_tick_advances_time() raises:
    var w = _world()
    var start = w.time()
    var sends = 0
    for _ in range(40):
        if w.tick():
            sends += 1
    assert_equal(w.time(), start + 40)
    assert_equal(w.current_tick(), 40)
    assert_equal(sends, 2)


def test_chunk_pos_from_block() raises:
    assert_true(chunk_pos_from_block(-0.5, 15.9) == ChunkPos(-1, 0))
    assert_true(chunk_pos_from_block(16.0, -16.0) == ChunkPos(1, -1))
    assert_true(chunk_key(ChunkPos(-1, 0)) != chunk_key(ChunkPos(0, -1)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
