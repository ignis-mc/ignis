from ignis.block.cube.pos import Pos
from ignis.block.cube.range import Range
from ignis.internal.rand import Rand
from ignis.world.chunk.chunk import Chunk
from ignis.world.chunk.column import Column
from ignis.world.dimension import NETHER, OVERWORLD
from ignis.world.position import ChunkPos
from ignis.world.provider import MemoryProvider, NopProvider, uuid_key
from ignis.world.settings import default_settings
from minecraft.protocol.uuid import UUID
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_nop_provider() raises:
    var p = NopProvider()
    assert_false(p.settings())
    assert_false(p.load_column(ChunkPos(0, 0), OVERWORLD))
    p.store_column(ChunkPos(0, 0), OVERWORLD, Column(Chunk(0, Range(0, 15))))
    assert_false(p.load_column(ChunkPos(0, 0), OVERWORLD))
    assert_false(p.load_player_spawn_position(UUID()))


def test_memory_provider() raises:
    var p = MemoryProvider()
    var c = Chunk(0, Range(0, 15))
    c.set_block(1, 2, 3, 0, 9)
    p.store_column(ChunkPos(4, 5), OVERWORLD, Column(c^))
    assert_equal(p.column_count(), 1)
    var back = p.load_column(ChunkPos(4, 5), OVERWORLD)
    assert_equal(back.value().chunk.block(1, 2, 3, 0), 9)
    # Columns are per dimension.
    assert_false(p.load_column(ChunkPos(4, 5), NETHER))
    var r = Rand(1, 2)
    var s = default_settings(r)
    s.name = "Saved"
    p.save_settings(s)
    assert_equal(p.settings().value().name, "Saved")
    p.save_player_spawn_position(UUID(), Pos(1, 2, 3))
    assert_equal(p.load_player_spawn_position(UUID()).value(), Pos(1, 2, 3))


def test_uuid_key() raises:
    var b = List[UInt8](length=16, fill=0)
    b[15] = 1
    b[0] = 2
    var k = uuid_key(UUID(Span(b)))
    assert_equal(k, (UInt128(2) << 120) | 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
