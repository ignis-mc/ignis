from ignis.internal.fs import read_file
from ignis.world.mcdb.leveldat.data import Data
from ignis.world.mcdb.leveldat.level_dat import LevelDat
from minecraft.nbt.decode import decode
from minecraft.nbt.nbt import LITTLE_ENDIAN
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def test_dragonfly_level_dat_round_trips_byte_for_byte() raises:
    # Written by Dragonfly's mcdb in interop/mcdb `world-write`.
    var raw = read_file("test/data/mcdb/dragonfly-world/level.dat")
    var l = LevelDat.read(Span(raw))
    assert_equal(l.ver(), 10)
    var d = l.unmarshal()
    assert_equal(d.level_name, "Ignis Fixture")
    assert_equal(d.spawn_y, 70)
    assert_equal(d.game_type, 1)
    assert_equal(d.difficulty, 3)
    assert_equal(len(d.extra.children(d.extra.root())), 0)
    var out = LevelDat()
    out.marshal(d)
    assert_true(out.bytes() == raw)


def test_unknown_fields_are_kept() raises:
    var raw = read_file("test/data/mcdb/dragonfly-world/level.dat")
    var d = LevelDat.read(Span(raw)).unmarshal()
    _ = d.extra.put_string(d.extra.root(), "SomeFutureField", "kept")
    var l = LevelDat()
    l.marshal(d)
    var back = LevelDat.read(Span(l.bytes())).unmarshal()
    assert_equal(
        back.extra.get_string(back.extra.root(), "SomeFutureField"), "kept"
    )


def test_errors() raises:
    with assert_raises(contains="header"):
        _ = LevelDat.read([UInt8(1), 2])
    with assert_raises(contains="read data"):
        _ = LevelDat.read([UInt8(10), 0, 0, 0, 100, 0, 0, 0, 1])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
