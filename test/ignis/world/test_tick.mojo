from ignis.block.cube.pos import Pos
from ignis.internal.rand import Rand
from ignis.world.position import ChunkPos
from ignis.world.tick import (
    RandUint4,
    ScheduledTick,
    ScheduledTickQueue,
    any_within_distance,
)
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_schedule_and_take_due() raises:
    var q = ScheduledTickQueue(10)
    q.schedule(Pos(1, 2, 3), 7, 99, 100)
    assert_equal(q.ticks[0].t, 12)
    # An earlier update for the same block and position is ignored while
    # a later one is pending; another block is not.
    q.schedule(Pos(1, 2, 3), 7, 99, 50)
    q.schedule(Pos(1, 2, 3), 8, 100, 50)
    assert_equal(len(q.ticks), 2)
    var due = q.take_due(11)
    assert_equal(len(due), 1)
    assert_equal(due[0].bhash, 100)
    assert_equal(len(q.take_due(12)), 1)
    assert_equal(len(q.ticks), 0)
    # Once processed, the same update can be scheduled again.
    q.schedule(Pos(1, 2, 3), 7, 99, 50)
    assert_equal(len(q.ticks), 1)


def test_chunks() raises:
    var q = ScheduledTickQueue(0)
    q.schedule(Pos(1, 0, 1), 1, 1, 50)
    q.schedule(Pos(17, 0, 1), 1, 1, 50)
    assert_equal(len(q.from_chunk(ChunkPos(1, 0))), 1)
    q.remove_chunk(ChunkPos(0, 0))
    assert_equal(len(q.ticks), 1)
    q.add([ScheduledTick(Pos(2, 0, 2), 1, 5, 9)])
    assert_equal(len(q.ticks), 2)


def test_rand_uint4() raises:
    var r = Rand(1, 2)
    var check = Rand(1, 2)
    var first = check.uint64()
    var g = RandUint4()
    for i in range(16):
        assert_equal(UInt64(g.uint4(r)), (first >> UInt64(4 * i)) & 0xF)


def test_any_within_distance() raises:
    var loaded: List[ChunkPos] = [ChunkPos(0, 0)]
    assert_true(any_within_distance(ChunkPos(3, 4), loaded, 5))
    assert_false(any_within_distance(ChunkPos(4, 4), loaded, 5))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
