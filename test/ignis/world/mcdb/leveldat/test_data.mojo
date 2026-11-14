from ignis.block.cube.pos import Pos
from ignis.world.mcdb.leveldat.data import Data
from minecraft.nbt.tree import Tree
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_fill_default_and_settings() raises:
    var d = Data()
    d.fill_default()
    assert_equal(d.level_name, "World")
    assert_equal(d.storage_version, 9)
    assert_equal(d.spawn_y, 32767)
    assert_equal(d.max_command_chain_length, 65535)
    assert_equal(d.abilities.walk_speed, 0.1)
    assert_equal(d.network_version, 2225)
    assert_equal(d.inventory_version, "1.26.60")
    var s = d.settings()
    assert_equal(d.world_start_count, 1)
    assert_equal(s.default_game_mode.id, 1)
    assert_equal(s.difficulty.id, 2)
    assert_true(s.raining)
    s.spawn = Pos(4, 5, 6)
    s.raining = False
    d.put_settings(s)
    assert_equal(d.limited_world_origin_z, 6)
    assert_equal(d.rain_level, 0)


def test_wrong_type_raises() raises:
    var t = Tree()
    _ = t.put_int(t.root(), "LevelName", 5)
    with assert_raises(contains="LevelName"):
        _ = Data.unmarshal(t)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
