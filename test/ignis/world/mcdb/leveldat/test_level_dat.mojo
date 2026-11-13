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


def test_reads_vanilla_level_dat() raises:
    # Saved by the vanilla 1.26.60 client for a new world. Dragonfly
    # v0.11.6 refuses it ("unexpected named tag
    # '.editorLevelMigrationVersion'"); here unknown fields are kept and
    # written back.
    var raw = read_file("test/data/mcdb/vanilla-1.26.60-level.dat")
    var l = LevelDat.read(Span(raw))
    assert_equal(l.ver(), 10)
    var d = l.unmarshal()
    assert_equal(d.level_name, "My World")
    assert_equal(d.spawn_x, 309)
    assert_equal(d.spawn_z, 172)
    assert_equal(d.minimum_compatible_client_version[1], 26)
    assert_true(d.extra.has(d.extra.root(), "editorLevelMigrationVersion"))
    var out = LevelDat()
    out.marshal(d)
    var back = LevelDat.read(Span(out.bytes())).unmarshal()
    assert_equal(back.level_name, "My World")
    assert_equal(
        len(back.extra.children(back.extra.root())),
        len(d.extra.children(d.extra.root())),
    )
    # Every field of the original is present after the round trip.
    var orig = decode(Span(l.data), LITTLE_ENDIAN)
    var again = decode(Span(out.data), LITTLE_ENDIAN)
    for c in orig.children(orig.root()):
        assert_true(again.has(again.root(), orig.name(c)), orig.name(c))


def test_errors() raises:
    with assert_raises(contains="header"):
        _ = LevelDat.read([UInt8(1), 2])
    with assert_raises(contains="read data"):
        _ = LevelDat.read([UInt8(10), 0, 0, 0, 100, 0, 0, 0, 1])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
