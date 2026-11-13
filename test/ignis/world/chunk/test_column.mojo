from ignis.block.cube.pos import Pos
from ignis.block.cube.range import Range
from ignis.world.chunk.chunk import Chunk
from ignis.world.chunk.column import Column, ScheduledBlockUpdate
from std.testing import TestSuite, assert_equal


def test_column() raises:
    var c = Column(Chunk(0, Range(0, 15)))
    assert_equal(len(c.entities), 0)
    assert_equal(c.tick, 0)
    c.scheduled_blocks.append(ScheduledBlockUpdate(Pos(1, 2, 3), 4, 5))
    var d = c.copy()
    assert_equal(d.scheduled_blocks[0].tick, 5)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
