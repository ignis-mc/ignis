from ignis.block.register import vanilla_block_registry
from ignis.internal.fs import join
from ignis.world.dimension import END, NETHER, OVERWORLD
from ignis.world.mcdb.db import DB
from ignis.world.mcdb.iterator import ColumnIterator, IteratorRange
from ignis.world.position import ChunkPos
from std.memory import ArcPointer
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.tempdir import copy_dir, remove_all, temp_dir


def _positions(mut db: DB, var r: IteratorRange) raises -> List[String]:
    var out = List[String]()
    var it = ColumnIterator(db, r^)
    while it.next(db):
        out.append(String(it.dimension().id, ":", it.position()))
    return out^


def test_ranges() raises:
    var br = ArcPointer(vanilla_block_registry())
    var dir = temp_dir("mcdb")
    copy_dir("test/data/mcdb/dragonfly-world", dir)
    var db = DB.open(dir, br)
    assert_equal(len(_positions(db, IteratorRange())), 6)
    var nether = IteratorRange()
    nether.dimension = NETHER
    assert_equal(_positions(db, nether^), ["1:(0, 0)"])
    var box = IteratorRange(ChunkPos(0, 0), ChunkPos(2, 2), OVERWORLD)
    assert_equal(len(_positions(db, box^)), 2)
    assert_true(IteratorRange().within(ChunkPos(-100, 5), END))
    _ = db^
    remove_all(dir)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
