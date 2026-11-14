from ignis.block.cube.pos import Pos
from ignis.block.register import vanilla_block_registry
from ignis.internal.fs import exists, join, read_file
from ignis.world.chunk.column import Column
from ignis.world.dimension import NETHER, OVERWORLD
from ignis.world.mcdb.db import DB, entity_index, index
from ignis.world.position import ChunkPos
from minecraft.protocol.uuid import UUID
from std.memory import ArcPointer
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.mcdb_world import dump, write_fixture
from support.tempdir import copy_dir, remove_all, temp_dir
from support.world_vectors import flat_chunk, simple_chunk


def _copy_fixture(dst: String) raises:
    copy_dir("test/data/mcdb/dragonfly-world", dst)


def test_loads_dragonfly_world() raises:
    # interop/mcdb `world-write` stored the world with Dragonfly's mcdb
    # (still in its journal); `world-dump` wrote what Dragonfly loads.
    var br = ArcPointer(vanilla_block_registry())
    var dir = temp_dir("mcdb")
    _copy_fixture(dir)
    var db = DB.open(dir, br)
    var got = dump(db)
    assert_equal(
        got, String(from_utf8=read_file("test/data/mcdb/dragonfly-world.txt"))
    )
    _ = db^
    remove_all(dir)


def test_written_world_loads_back_identically() raises:
    var br = ArcPointer(vanilla_block_registry())
    var dir = temp_dir("mcdb")
    write_fixture(dir, br)
    assert_true(exists(join(dir, "level.dat")))
    assert_equal(
        String(from_utf8=read_file(join(dir, "levelname.txt"))), "Ignis Fixture"
    )
    var db = DB.open(dir, br)
    assert_equal(
        dump(db),
        String(from_utf8=read_file("test/data/mcdb/dragonfly-world.txt")),
    )
    _ = db^
    remove_all(dir)


def test_missing_column_and_overwrite() raises:
    var br = ArcPointer(vanilla_block_registry())
    var dir = temp_dir("mcdb")
    var db = DB.open(dir, br)
    assert_false(Bool(db.load_column(ChunkPos(0, 0), OVERWORLD)))
    db.store_column(ChunkPos(0, 0), NETHER, Column(simple_chunk(br[])))
    # The same position in another dimension is a different column.
    assert_false(Bool(db.load_column(ChunkPos(0, 0), OVERWORLD)))
    db.store_column(ChunkPos(0, 0), OVERWORLD, Column(flat_chunk(br[])))
    db.store_column(ChunkPos(0, 0), OVERWORLD, Column(simple_chunk(br[])))
    var c = db.load_column(ChunkPos(0, 0), OVERWORLD)
    assert_true(c.value().chunk.equals(simple_chunk(br[])))
    _ = db^
    remove_all(dir)


def test_player_spawn() raises:
    var br = ArcPointer(vanilla_block_registry())
    var dir = temp_dir("mcdb")
    var db = DB.open(dir, br)
    var id = UUID.parse("00000000-0000-4000-8000-000000000001")
    assert_false(Bool(db.load_player_spawn_position(id)))
    db.save_player_spawn_position(id, Pos(1, 2, 3))
    db.save_player_spawn_position(id, Pos(-4, 5, -6))
    assert_true(db.load_player_spawn_position(id).value() == Pos(-4, 5, -6))
    _ = db^
    remove_all(dir)


def test_keys() raises:
    # Go index: X and Z little-endian, the dimension only outside the
    # overworld.
    assert_equal(
        index(ChunkPos(1, -1), OVERWORLD),
        [UInt8(1), 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF],
    )
    assert_equal(len(index(ChunkPos(1, -1), NETHER)), 12)
    assert_equal(index(ChunkPos(0, 0), NETHER)[8], 1)
    var e = entity_index(-2)
    assert_equal(String(from_utf8=Span(e)[:11]), "actorprefix")
    assert_equal(e[11], 0xFE)
    assert_equal(e[18], 0xFF)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
