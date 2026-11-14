from ignis.mgl64 import Vec3
from ignis.player.playerdb.json import Data
from ignis.player.playerdb.leveldb import Provider
from minecraft.protocol.uuid import UUID
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.tempdir import remove_all, temp_dir


def test_save_load_reopen() raises:
    var dir = temp_dir("playerdb")
    var id = UUID.parse("6a5d3e2f-1c2b-4a3d-9e8f-0a1b2c3d4e5f")
    var d = Data()
    d.username = "Steve"
    d.position = Vec3(10.5, -59, -3.25)
    d.game_mode = 1
    var p = Provider(dir)
    assert_false(Bool(p.load(id)))
    p.save(id, d)
    p.close()
    _ = p^
    var again = Provider(dir)
    var got = again.load(id).value().copy()
    assert_equal(got.username, "Steve")
    assert_true(got.position == Vec3(10.5, -59, -3.25))
    assert_equal(got.game_mode, 1)
    _ = again^
    remove_all(dir)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
