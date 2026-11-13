from ignis.block.air import Air
from ignis.block.bedrock import Bedrock
from ignis.block.dirt import Dirt
from ignis.block.grass import Grass
from ignis.block.register import vanilla_block_registry
from ignis.block.stone import Stone
from ignis.world.block import Block
from ignis.world.block_registry import (
    UNKNOWN_KIND,
    BasicBlockRegistry,
    BlockInfo,
)
from ignis.world.block_state import BlockState, Properties
from nethernet.crypto.sha256 import Sha256
from nethernet.wire import hex_encode
from std.collections import Dict
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def _vectors() raises -> Dict[String, String]:
    var out = Dict[String, String]()
    with open("test/data/world/vectors.txt", "r") as f:
        for line in f.read().split("\n"):
            if line.byte_length() == 0:
                continue
            var parts = line.split(" ", 1)
            out[String(parts[0])] = String(parts[1])
    return out^


def _line(br: BasicBlockRegistry, rid: UInt32) raises -> String:
    var hash = br.runtime_id_to_hash(rid).value()
    var hex = String()
    for i in range(4):
        var b = UInt8((hash >> UInt32(24 - 8 * i)) & 0xFF)
        hex += hex_encode(Span([b]))
    ref s = br.state(rid)
    return String(t"{rid}\t{hex}\t{s.name}\t{s.properties}")


def test_every_state_matches_dragonfly() raises:
    var br = vanilla_block_registry()
    var v = _vectors()
    assert_equal(String(br.block_count()), v["states.count"])
    assert_equal(String(br.air_runtime_id()), v["states.air"])
    assert_equal(String(br.bit_size()), v["states.bit_size"])
    var h = Sha256()
    for rid in range(br.block_count()):
        var line = _line(br, UInt32(rid)) + "\n"
        h.update(line.as_bytes())
    var digest = h.finish()
    assert_equal(hex_encode(Span(digest)), v["states.sha256"])


def test_sample_lines() raises:
    var br = vanilla_block_registry()
    var n = 0
    with open("test/data/world/block_states_sample.txt", "r") as f:
        for line in f.read().split("\n"):
            if line.byte_length() == 0:
                continue
            var rid = UInt32(Int(line.split("\t", 1)[0]))
            assert_equal(_line(br, rid), String(line))
            # Name and properties lead back to the same runtime ID and hash.
            ref s = br.state(rid)
            assert_equal(
                br.state_to_runtime_id(s.name, s.properties).value(), rid
            )
            var hash = br.runtime_id_to_hash(rid).value()
            assert_equal(br.hash_to_runtime_id(hash).value(), rid)
            n += 1
    assert_true(n > 200)


def _check[
    T: Block
](br: BasicBlockRegistry, v: Dict[String, String], name: String, b: T) raises:
    var rid = br.block_runtime_id(b)
    assert_equal(String(rid), v["block." + name + ".rid"])
    assert_equal(String(br.block_hash(b)), v["block." + name + ".hash"])
    assert_true(br.is_block[T](rid))
    assert_equal(br.block[T](rid).value().hash(), b.hash())
    assert_true(br.runtime_id_to_state(rid).value() == b.encode_block())


def test_implemented_blocks() raises:
    var br = vanilla_block_registry()
    var v = _vectors()
    _check(br, v, "air", Air())
    _check(br, v, "stone", Stone())
    _check(br, v, "smooth_stone", Stone(smooth=True))
    _check(br, v, "grass", Grass())
    _check(br, v, "dirt", Dirt())
    _check(br, v, "coarse_dirt", Dirt(coarse=True))
    _check(br, v, "bedrock", Bedrock())
    _check(br, v, "bedrock_burning", Bedrock(infinite_burning=True))
    assert_equal(br.air(), br.block_runtime_id(Air()))


def test_typed_lookup_rejects_other_types() raises:
    var br = vanilla_block_registry()
    var stone = br.block_runtime_id(Stone())
    assert_false(br.is_block[Dirt](stone))
    assert_false(br.block[Dirt](stone))
    var water = br.block_by_name(
        "minecraft:water", Properties().with_int("liquid_depth", 0)
    ).value()
    assert_equal(br.kind(water), UNKNOWN_KIND)
    assert_false(br.is_block[Air](water))
    assert_false(br.is_block[Air](UInt32(br.block_count())))


def test_light_info() raises:
    var br = vanilla_block_registry()
    assert_equal(br.filtering_block(br.air()), 0)
    assert_equal(br.filtering_block(br.block_runtime_id(Stone())), 15)
    # States without a type default to fully opaque, as in Go.
    var water = br.block_by_name(
        "minecraft:water", Properties().with_int("liquid_depth", 0)
    ).value()
    assert_equal(br.filtering_block(water), 15)
    assert_equal(br.light_block(br.air()), 0)


def test_state_to_runtime_id_falls_back_to_default() raises:
    var br = vanilla_block_registry()
    var bedrock = br.block_runtime_id(Bedrock())
    assert_equal(
        br.state_to_runtime_id("minecraft:bedrock", Properties()).value(),
        br.state_to_runtime_id(
            "minecraft:bedrock",
            br.default_properties("minecraft:bedrock").value(),
        ).value(),
    )
    assert_equal(
        br.state_to_runtime_id(
            "minecraft:bedrock", Properties().with_byte("infiniburn_bit", 0)
        ).value(),
        bedrock,
    )
    assert_false(
        br.state_to_runtime_id("minecraft:no_such_block", Properties())
    )
    # Exact lookups do not fall back.
    assert_false(br.block_by_name("minecraft:bedrock", Properties()))


def test_property_types_are_distinct() raises:
    var br = vanilla_block_registry()
    # liquid_depth is an int32; a byte with the same value is another state.
    assert_true(
        br.block_by_name(
            "minecraft:water", Properties().with_int("liquid_depth", 3)
        )
    )
    assert_false(
        br.block_by_name(
            "minecraft:water", Properties().with_byte("liquid_depth", 3)
        )
    )


def test_registration_errors() raises:
    var br = BasicBlockRegistry()
    br.register_block_state(BlockState("minecraft:stone"))
    with assert_raises(contains="twice"):
        br.register_block_state(BlockState("minecraft:stone"))
    with assert_raises(contains="not registered"):
        br.register_block(Dirt())
    br.register_block(Stone())
    with assert_raises(contains="already registered"):
        br.register_block(Stone())
    with assert_raises(contains="air"):
        br.finalize()
    br.register_block_state(BlockState("minecraft:air"))
    br.finalize()
    br.finalize()
    with assert_raises(contains="finalized"):
        br.register_block_state(BlockState("minecraft:dirt"))
    assert_equal(br.block_count(), 2)
    assert_equal(br.bit_size(), 2)


def test_block_info_bits() raises:
    var info = BlockInfo(0)
    info.set_light_filter(15)
    info.set_light(7)
    info.set(2)
    assert_equal(info.get_light_filter(), 15)
    assert_equal(info.get_light(), 7)
    assert_true(info.get(2))
    assert_false(info.get(1))
    info.set_light_filter(3)
    assert_equal(info.get_light_filter(), 3)
    assert_equal(info.get_light(), 7)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
