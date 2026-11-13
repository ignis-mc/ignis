from ignis.block.register import vanilla_block_registry
from ignis.internal.mgl64 import Vec3
from ignis.world.biome.plains import Plains
from ignis.world.chunk.chunk import Chunk
from ignis.world.dimension import Dimension
from ignis.world.generator.flat import Flat
from ignis.world.loader import Loader, Viewer, chunk_distance
from ignis.world.position import ChunkPos
from ignis.world.world import Settings, World
from std.testing import TestSuite, assert_equal, assert_false, assert_true


struct _Recorder(Viewer):
    var seen: List[ChunkPos]

    def __init__(out self):
        self.seen = List[ChunkPos]()

    def view_chunk(mut self, pos: ChunkPos, dim: Dimension, mut c: Chunk):
        self.seen.append(pos)


def _world() raises -> World[Flat]:
    var br = vanilla_block_registry()
    var layers: List[UInt32] = [br.air()]
    return World(br^, Flat(Plains(), layers^), Settings())


def test_chunk_distance() raises:
    assert_equal(chunk_distance(ChunkPos(0, 0), ChunkPos(3, 4)), 5)
    assert_equal(chunk_distance(ChunkPos(0, 0), ChunkPos(1, 1)), 1)


def test_loads_nearest_first() raises:
    var w = _world()
    var v = _Recorder()
    var l = Loader(2, ChunkPos(0, 0))
    # Radius 2 holds the 21 chunks within rounded distance 2.
    assert_equal(l.queued_count(), 21)
    l.load(w, v, 4)
    assert_equal(len(v.seen), 4)
    assert_true(v.seen[0] == ChunkPos(0, 0))
    for i in range(1, 4):
        assert_equal(chunk_distance(v.seen[i], ChunkPos(0, 0)), 1)
    l.load(w, v, 100)
    assert_equal(len(v.seen), 21)
    assert_equal(l.loaded_count(), 21)
    assert_equal(l.queued_count(), 0)


def test_move_evicts_and_queues() raises:
    var w = _world()
    var v = _Recorder()
    var l = Loader(1, ChunkPos(0, 0))
    l.load(w, v, 100)
    # Diagonals round to distance 1, so radius 1 is a 3x3 square.
    assert_equal(l.loaded_count(), 9)
    l.move(Vec3(17, 0, 0))
    assert_true(l.pos() == ChunkPos(1, 0))
    # Columns x=0 and x=1 stay; column x=2 is new.
    assert_equal(l.loaded_count(), 6)
    assert_equal(l.queued_count(), 3)
    assert_false(l.chunk_loaded(ChunkPos(-1, 0)))
    l.load(w, v, 100)
    assert_equal(len(v.seen), 12)
    assert_true(l.chunk_loaded(ChunkPos(2, 0)))


def test_change_radius() raises:
    var w = _world()
    var v = _Recorder()
    var l = Loader(2, ChunkPos(0, 0))
    l.load(w, v, 100)
    l.change_radius(1)
    assert_equal(l.loaded_count(), 9)
    assert_equal(l.queued_count(), 0)
    l.close()
    assert_equal(l.loaded_count(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
