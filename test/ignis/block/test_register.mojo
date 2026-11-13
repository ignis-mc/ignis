from ignis.block.bedrock import Bedrock
from ignis.block.break_info import BreakInfo
from ignis.block.grass import Grass
from ignis.block.hash import (
    HASH_CUSTOM_BLOCK_BASE,
    HASH_GRASS,
    HASH_NETHER_BRICKS,
    HASH_SLAB,
    HASH_STAIRS,
)
from ignis.block.register import (
    VanillaBlocks,
    break_info,
    vanilla_block_registry,
)
from ignis.world.block_registry import UNKNOWN_KIND, BasicBlockRegistry
from std.memory import bitcast
from std.testing import TestSuite, assert_equal, assert_true


def _tools() -> List[Tuple[Int, Int]]:
    """The (tool type, harvest level) pairs `interop/world` evaluates
    `Harvestable` and `Effective` with, in its order."""
    var out: List[Tuple[Int, Int]] = [(-1, 0)]
    # Wood, gold, stone, copper, iron, diamond, netherite.
    for level in [1, 1, 2, 2, 3, 4, 4]:
        for t in [0, 1, 2, 3, 5]:
            out.append((t, level))
    out.append((4, 1))
    return out^


def _float_hex(f: Float64) -> String:
    var bits = bitcast[DType.uint64](f)
    var s = String()
    for i in range(16):
        var nibble = Int((bits >> UInt64(60 - 4 * i)) & 0xF)
        s += String("0123456789abcdef"[byte=nibble])
    return s^


def _hex(v: UInt64) -> String:
    if v == 0:
        return "0"
    var s = String()
    var started = False
    for i in range(16):
        var nibble = Int((v >> UInt64(60 - 4 * i)) & 0xF)
        if nibble != 0 or started:
            started = True
            s += String("0123456789abcdef"[byte=nibble])
    return s^


def _break_line(info: Optional[BreakInfo]) -> String:
    if not info:
        return "-"
    var b = info.value()
    var tools = _tools()
    var harvest = UInt64(0)
    var effective = UInt64(0)
    for i in range(len(tools)):
        if b.harvestable.matches(tools[i][0], tools[i][1]):
            harvest |= UInt64(1) << UInt64(i)
        if b.effective.matches(tools[i][0], tools[i][1]):
            effective |= UInt64(1) << UInt64(i)
    return String(
        t"{_float_hex(b.hardness)},{_float_hex(b.blast_resistance)},"
        t"{_hex(harvest)},{_hex(effective)},{b.xp_drops.min},{b.xp_drops.max}"
    )


def _fixed_go_hash(kind: UInt64, hash: UInt64) -> UInt64:
    """Returns the state hash Ignis gives the block Dragonfly registers at a
    runtime ID. They differ only where Ignis fixes a Dragonfly bug: Go swaps
    the plain and red nether brick slabs and stairs (see `slab_type.mojo`)."""
    if kind != HASH_SLAB and kind != HASH_STAIRS:
        return hash
    var inner_kind = hash & 0xFFFF
    var inner_state = (hash >> 16) & 0xFFFF
    if inner_kind == HASH_NETHER_BRICKS and inner_state <= 1:
        return hash ^ (1 << 16)
    return hash


def test_vanilla_blocks() raises:
    assert_true(VanillaBlocks.contains(HASH_GRASS))
    assert_true(not VanillaBlocks.contains(HASH_CUSTOM_BLOCK_BASE))


def test_vanilla_block_registry() raises:
    var br = vanilla_block_registry()
    assert_true(br.finalized())
    assert_true(br.is_block[Grass](br.block_runtime_id(Grass())))
    var burning = br.block_runtime_id(Bedrock(infinite_burning=True))
    assert_true(br.block[Bedrock](burning).value().infinite_burning)


def test_every_block_matches_dragonfly() raises:
    """Every runtime ID Dragonfly registers a block for (`blocks.txt` from
    `interop/world`) holds a block of the same type and state here, which
    encodes to the registered name and properties and has the same light
    values and break info, and every other runtime ID stays unknown."""
    var br = vanilla_block_registry()
    var expected = Dict[Int, String]()
    var types = Dict[UInt64, String]()
    with open("test/data/world/blocks.txt", "r") as f:
        for line in f.read().split("\n"):
            if line.byte_length() == 0:
                continue
            var parts = line.split("\t")
            var kind = UInt64(Int(parts[2]))
            types[kind] = String(parts[1])
            if VanillaBlocks.contains(kind):
                expected[Int(parts[0])] = String(line)
    var missing = List[String]()
    for e in types.items():
        if not VanillaBlocks.contains(e.key):
            missing.append(e.value)
    var checked = 0
    for rid in range(br.block_count()):
        var r = UInt32(rid)
        var kind = br.kind(r)
        if rid not in expected:
            assert_equal(
                kind, UNKNOWN_KIND, String(t"rid {rid} should be unknown")
            )
            continue
        var parts = expected[rid].split("\t")
        var name = String(parts[1])
        var go_hash = _fixed_go_hash(kind, UInt64(Int(parts[3])))
        var want = String("\t").join(parts[:3])
        want += String(t"\t{go_hash}\t") + String("\t").join(parts[4:])
        var hash = br.state_hash(r)
        var s = VanillaBlocks.encode(kind, hash)
        assert_true(Bool(s), String(t"rid {rid} ({name}) has no type"))
        assert_true(
            s.value() == br.state(r), String(t"rid {rid} encodes differently")
        )
        var got = String(
            t"{rid}\t{name}\t{kind}\t{hash}\t{br.light_block(r)}\t"
            t"{br.filtering_block(r)}\t"
        )
        # TODO(world-runtime): compare the registry flags (NBT, random tick,
        # liquid, liquid displacing) once those traits exist; blocks.txt has
        # Dragonfly's values.
        var flags = String(parts[6])
        got += flags + "\t" + _break_line(break_info(kind, hash))
        assert_equal(got, want)
        checked += 1
    for m in missing:
        print("not ported:", m)
    assert_equal(len(missing), 0, "every Dragonfly block type is ported")
    assert_equal(checked, len(expected))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
