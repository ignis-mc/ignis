"""The disk encoding of chunks (`encode.disk_encode`, `decode.disk_decode`,
`encoding.encode_disk_block_state`, `encoding.decode_disk_block_state`)."""

from ignis.block.register import vanilla_block_registry
from ignis.internal.fs import read_file
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.chunk.conversion import Upgrades
from ignis.world.chunk.decode import disk_decode
from ignis.world.chunk.encode import (
    CURRENT_BLOCK_VERSION,
    SerialisedData,
    disk_encode,
)
from ignis.world.dimension import OVERWORLD
from minecraft.nbt.decode import decode_from
from minecraft.nbt.encode import encode_to
from minecraft.nbt.nbt import (
    LITTLE_ENDIAN,
    NETWORK_LITTLE_ENDIAN,
    TAG_BYTE,
    TAG_INT,
    TAG_STRING,
)
from minecraft.nbt.tree import Tag, Tree
from nethernet.crypto.sha256 import sha256
from nethernet.wire import hex_encode
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.world_vectors import (
    biome_chunk,
    flat_chunk,
    mixed_chunk,
    new_chunk,
    simple_chunk,
)


def test_disk_round_trip() raises:
    var br = vanilla_block_registry()
    var up = Upgrades.load()
    for c in [
        new_chunk(br),
        simple_chunk(br),
        biome_chunk(br),
        mixed_chunk(br),
        flat_chunk(br),
    ]:
        var d = disk_encode(c, br)
        var back = disk_decode(br, up, d, OVERWORLD.range())
        assert_true(back.equals(c))
        assert_false(back.legacy_states())


def _decode_one(
    br: BasicBlockRegistry, up: Upgrades, entry: Tree
) raises -> String:
    # Mirrors interop/mcdb/upgrade.go: one palette entry in a version 9
    # sub-chunk with a single 0-bit storage.
    var sub: List[UInt8] = [9, 1, 0xFC, 0]
    encode_to(entry, LITTLE_ENDIAN, sub)
    var d = SerialisedData()
    d.sub_chunks.append(sub^)
    for _ in range(23):
        d.sub_chunks.append(List[UInt8]())
    try:
        var c = disk_decode(br, up, d, OVERWORLD.range())
        return String(c.block(0, -64, 0, 0), "|", 1 if c.legacy_states() else 0)
    except:
        return "ERR|0"


def _copy_states(src: Tree, s: Tag, mut t: Tree, dst: Tag) raises -> String:
    # Copies a states compound and returns it formatted like Go's fmtProps.
    var names = List[String]()
    for c in src.children(s):
        names.append(src.name(c))
        var ty = src.type_of(c)
        if ty == TAG_BYTE:
            _ = t.put_byte(dst, src.name(c), src.as_byte(c))
        elif ty == TAG_INT:
            _ = t.put_int(dst, src.name(c), src.as_int(c))
        elif ty == TAG_STRING:
            _ = t.put_string(dst, src.name(c), src.as_string(c))
    sort(names)
    var out = String()
    for i in range(len(names)):
        if i > 0:
            out += ","
        var c = src.get(s, names[i]).value()
        var ty = src.type_of(c)
        if ty == TAG_BYTE:
            out += String(names[i], "=b:", src.as_byte(c))
        elif ty == TAG_INT:
            out += String(names[i], "=i:", src.as_int(c))
        else:
            out += String(names[i], "=s:", src.as_string(c))
    return out^


def test_decoding_matches_dragonfly() raises:
    # interop/mcdb `upgrade-vectors`: every pre-1.13 entry of
    # legacy_states.nbt, every flattened state in it at its own version and
    # every registered state at the current version, decoded by Dragonfly.
    var br = vanilla_block_registry()
    var up = Upgrades.load()
    var data = read_file("resources/legacy_states.nbt")
    var olds = List[Tree]()
    var pos = 0
    while pos < len(data):
        olds.append(decode_from(Span(data), pos, NETWORK_LITTLE_ENDIAN))
    var lines = List[String]()
    for ref e in olds:
        var old = e.get_compound(e.root(), "legacy")
        var name = e.get_string(old, "name")
        var meta = e.get_short(old, "meta")
        var t = Tree()
        _ = t.put_string(t.root(), "name", name)
        _ = t.put_short(t.root(), "val", meta)
        _ = t.put_int(t.root(), "version", 17694720)
        lines.append(
            String("L|", name, "|17694720|", meta, "|", _decode_one(br, up, t))
        )
    for ref e in olds:
        var upd = e.get_compound(e.root(), "updated")
        var name = e.get_string(upd, "name")
        var version = e.get_int(upd, "version")
        var t = Tree()
        _ = t.put_string(t.root(), "name", name)
        var props = _copy_states(
            e,
            e.get_compound(upd, "states"),
            t,
            t.put_compound(t.root(), "states"),
        )
        _ = t.put_int(t.root(), "version", version)
        lines.append(
            String(
                "U|",
                name,
                "|",
                version,
                "|",
                props,
                "|",
                _decode_one(br, up, t),
            )
        )
    for rid in range(br.block_count()):
        ref s = br.state(UInt32(rid))
        var t = Tree()
        _ = t.put_string(t.root(), "name", s.name)
        var st = t.put_compound(t.root(), "states")
        for ref p in s.properties.entries:
            if p.value.tag == TAG_STRING:
                _ = t.put_string(st, p.key, p.value.string)
            elif p.value.tag == TAG_INT:
                _ = t.put_int(st, p.key, p.value.int)
            else:
                _ = t.put_byte(st, p.key, UInt8(p.value.int))
        _ = t.put_int(t.root(), "version", CURRENT_BLOCK_VERSION)
        lines.append(
            String(
                "C|",
                s.name,
                "|",
                CURRENT_BLOCK_VERSION,
                "|",
                s.properties,
                "|",
                _decode_one(br, up, t),
            )
        )
    var want = String(
        from_utf8=read_file("test/data/world/upgrade_vectors.txt")
    ).split("\n")
    assert_equal(String(want[1]), String("count ", len(lines)))
    for i in range(2, len(want)):
        if want[i].byte_length() == 0:
            continue
        var parts = want[i].split(" ", 1)
        var idx = Int(String(parts[0]))
        assert_equal(lines[idx], String(parts[1]), String("line ", idx))
    var full = String()
    for l in lines:
        full += l
        full += "\n"
    assert_equal(
        String("sha256 ", hex_encode(Span(sha256(full.as_bytes())))),
        String(want[0]),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
