from ignis.world.loader import Loader, chunk_distance
from ignis.world.position import ChunkPos
from ignis.world.viewer import NopViewer
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_chunk_distance() raises:
    assert_equal(chunk_distance(ChunkPos(0, 0), ChunkPos(1, 1)), 1)
    assert_equal(chunk_distance(ChunkPos(0, 0), ChunkPos(2, 2)), 3)
    assert_equal(chunk_distance(ChunkPos(-3, 0), ChunkPos(0, 4)), 5)


def test_populate_load_queue() raises:
    var l = Loader[NopViewer](2, NopViewer())
    l.pos = ChunkPos(5, 5)
    l.populate_load_queue()
    assert_equal(len(l.load_queue), 21)
    # Nearest first: the centre, then distance 1, then distance 2.
    assert_equal(l.load_queue[0], ChunkPos(5, 5))
    for i in range(1, 9):
        assert_equal(chunk_distance(l.load_queue[i], l.pos), 1)
    for i in range(9, 21):
        assert_equal(chunk_distance(l.load_queue[i], l.pos), 2)
    l.loaded.add(ChunkPos(5, 5))
    l.populate_load_queue()
    assert_equal(len(l.load_queue), 20)


def test_queue_load() raises:
    var l = Loader[NopViewer](1, NopViewer())
    l.load_queue.clear()
    l.queue_load(ChunkPos(0, 1))
    l.queue_load(ChunkPos(0, 1))
    l.queue_load(ChunkPos(9, 9))
    assert_equal(len(l.load_queue), 1)
    assert_true(l.within_load_radius(ChunkPos(1, 1)))
    assert_false(l.within_load_radius(ChunkPos(2, 1)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
