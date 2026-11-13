from ignis.block.register import vanilla_block_registry
from ignis.internal.fs import exists, join
from ignis.leveldb.options import KIB
from ignis.world.mcdb.conf import Config
from std.memory import ArcPointer
from std.testing import TestSuite, assert_equal, assert_true
from support.tempdir import remove_all, temp_dir


def test_defaults_and_open() raises:
    var br = ArcPointer(vanilla_block_registry())
    var c = Config(br)
    assert_equal(c.ldb_options.block_size, 16 * KIB)
    var dir = temp_dir("mcdb")
    var db = c^.open(dir)
    assert_true(exists(join(dir, "db/CURRENT")))
    # A new world gets Dragonfly's default level.dat values.
    assert_equal(db.settings().value().name, "World")
    assert_equal(db.level_data().storage_version, 9)
    db.close()
    assert_true(exists(join(dir, "level.dat")))
    _ = db^
    remove_all(dir)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
