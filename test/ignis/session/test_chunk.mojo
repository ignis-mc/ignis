from ignis.block.register import vanilla_block_registry
from ignis.session.chunk import (
    network_chunk,
    sub_chunk_entry,
    sub_chunk_index,
)
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.chunk.chunk import Chunk
from ignis.world.dimension import OVERWORLD
from ignis.world.position import ChunkPos, SubChunkPos
from minecraft.protocol.block_pos import SubChunkPos as ProtocolSubChunkPos
from minecraft.protocol.packet.sub_chunk import SubChunk
from minecraft.protocol.sub_chunk import (
    SUB_CHUNK_RESULT_CHUNK_NOT_FOUND,
    SUB_CHUNK_RESULT_INDEX_OUT_OF_BOUNDS,
    SubChunkEntry,
    SubChunkOffset,
)
from minecraft.protocol.writer import Writer as ProtocolWriter
from nethernet.wire import hex_encode
from std.collections import Dict
from std.testing import TestSuite, assert_equal, assert_false
from support.world_vectors import (
    biome_chunk,
    flat_chunk,
    flat_chunk_dragonfly,
    load_vectors,
    new_chunk,
    simple_chunk,
)


def _sub_chunk_packet(br: BasicBlockRegistry, mut c: Chunk) raises -> SubChunk:
    """Go's subChunkPacket in interop/world: offsets y -5..21 at (0, 0) and
    one at (1, 0, 0), around sub-chunk (3, 0, -2)."""
    var centre = SubChunkPos(3, 0, -2)
    var offsets = List[SubChunkOffset]()
    for y in range(-5, 22):
        offsets.append(SubChunkOffset(0, Int8(y), 0))
    offsets.append(SubChunkOffset(1, 0, 0))
    var pk = SubChunk()
    pk.dimension = 0
    pk.position = ProtocolSubChunkPos()
    pk.position.x = centre.x()
    pk.position.y = centre.y()
    pk.position.z = centre.z()
    for offset in offsets:
        var ind = sub_chunk_index(centre, offset, OVERWORLD.range())
        if not ind:
            var e = SubChunkEntry()
            e.result = SUB_CHUNK_RESULT_INDEX_OUT_OF_BOUNDS
            e.offset = offset
            pk.sub_chunk_entries.append(e^)
            continue
        if offset.x != 0 or offset.z != 0:
            var e = SubChunkEntry()
            e.result = SUB_CHUNK_RESULT_CHUNK_NOT_FOUND
            e.offset = offset
            pk.sub_chunk_entries.append(e^)
            continue
        pk.sub_chunk_entries.append(sub_chunk_entry(offset, ind.value(), c, br))
    return pk^


def _check(
    br: BasicBlockRegistry, v: Dict[String, String], name: String, var c: Chunk
) raises:
    var w = ProtocolWriter()
    var level = network_chunk(ChunkPos(3, -2), 0, c)
    level.marshal(w)
    assert_equal(hex_encode(Span(w.take())), v[name + ".level_chunk"], name)
    var w2 = ProtocolWriter()
    var sub = _sub_chunk_packet(br, c)
    sub.marshal(w2)
    assert_equal(hex_encode(Span(w2.take())), v[name + ".sub_chunk"], name)


def test_empty() raises:
    var br = vanilla_block_registry()
    _check(br, load_vectors(), "empty", new_chunk(br))


def test_simple() raises:
    var br = vanilla_block_registry()
    _check(br, load_vectors(), "simple", simple_chunk(br))


def test_biomes() raises:
    var br = vanilla_block_registry()
    _check(br, load_vectors(), "biomes", biome_chunk(br))


def test_flat() raises:
    var br = vanilla_block_registry()
    var v = load_vectors()
    _check(br, v, "flat", flat_chunk_dragonfly(br))
    _check(br, v, "flat_fixed", flat_chunk(br))


def test_sub_chunk_index() raises:
    var r = OVERWORLD.range()
    assert_equal(
        sub_chunk_index(
            SubChunkPos(0, 0, 0), SubChunkOffset(0, 0, 0), r
        ).value(),
        4,
    )
    assert_equal(
        sub_chunk_index(
            SubChunkPos(0, -4, 0), SubChunkOffset(0, 0, 0), r
        ).value(),
        0,
    )
    assert_equal(
        sub_chunk_index(
            SubChunkPos(0, 19, 0), SubChunkOffset(0, 0, 0), r
        ).value(),
        23,
    )
    assert_false(
        sub_chunk_index(SubChunkPos(0, 20, 0), SubChunkOffset(0, 0, 0), r)
    )
    assert_false(
        sub_chunk_index(SubChunkPos(0, -5, 0), SubChunkOffset(0, 0, 0), r)
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
