"""Checks every vanilla biome and the biome definitions packet against
Dragonfly (`test/data/world/defs.txt` from `interop/world`)."""

from ignis.world.biome import BiomeRegistry, unknown_biome
from ignis.world.biome.plains import Plains
from ignis.world.biome.register import vanilla_biome_registry
from ignis.world.biome_definition import biome_definitions
from minecraft.protocol.packet.biome_definition_list import BiomeDefinitionList
from minecraft.protocol.writer import Writer
from nethernet.wire import hex_encode
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)
from support.go_values import f64, read_lines


def test_biomes_match_dragonfly() raises:
    var r = vanilla_biome_registry()
    var want = List[String]()
    for line in read_lines("test/data/world/defs.txt"):
        if line.startswith("biome\t"):
            var p = line.split("\t")
            # Drop the Go type name, which Mojo does not see.
            want.append(
                String("\t").join(p[1:2]) + "\t" + String("\t").join(p[3:])
            )
    var got = List[String]()
    for b in r.biomes():
        var w = b.water_colour
        got.append(
            String(
                t"{b.id}\t{b.name}\t{f64(b.temperature)}\t{f64(b.rainfall)}\t"
                t"{f64(b.depth)}\t{f64(b.scale)}\t{w.r},{w.g},{w.b},{w.a}\t"
            )
            + String(",").join(b.tags)
        )
    assert_equal(len(got), len(want))
    for i in range(len(got)):
        assert_equal(got[i], want[i])
    assert_equal(r.by_name("plains").value().copy().id, 1)
    assert_false(Bool(r.by_id(1000)))
    assert_equal(r.max_vanilla_id(), r.biomes()[len(r.biomes()) - 1].id)


def test_biome_definition_list_matches_dragonfly() raises:
    var r = vanilla_biome_registry()
    var defs = biome_definitions(r)
    var pk = BiomeDefinitionList()
    pk.biome_definitions = defs[0].copy()
    pk.string_list = defs[1].copy()
    var w = Writer()
    pk.marshal(w)
    var got = hex_encode(Span(w.take()))
    for line in read_lines("test/data/world/defs.txt"):
        if line.startswith("biome_definition_list\t"):
            assert_equal(got, String(line.split("\t")[1]))
            return
    raise Error("no biome_definition_list line")


def test_registry() raises:
    var r = BiomeRegistry()
    r.register(Plains())
    with assert_raises():
        r.register(Plains())
    var u = unknown_biome(300)
    assert_equal(u.name, "unknown")
    assert_equal(u.id, 300)
    assert_true(u.temperature == 0.5)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
