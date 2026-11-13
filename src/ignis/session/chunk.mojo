"""Chunk packets, ported from the payload-building parts of Dragonfly
`server/session/chunk.go`.

Dragonfly sends chunks with sub-chunk requests enabled
(`subChunkRequests = true`): `LevelChunk` carries only the biomes, and the
client then asks for sub-chunks, answered with `SubChunk` entries. These
functions build both without the client blob cache, and without block
entities, which come with the block entity port (Go appends their NBT after
the sub-chunk payload).
"""

from minecraft.protocol.block_pos import ChunkPos as ProtocolChunkPos
from minecraft.protocol.packet.level_chunk import LevelChunk
from minecraft.protocol.sub_chunk import (
    HEIGHT_MAP_DATA_HAS_DATA,
    HEIGHT_MAP_DATA_TOO_HIGH,
    HEIGHT_MAP_DATA_TOO_LOW,
    SUB_CHUNK_RESULT_SUCCESS,
    SUB_CHUNK_RESULT_SUCCESS_ALL_AIR,
    HeightMap as ProtocolHeightMap,
    SubChunkEntry,
    SubChunkOffset,
)

from ..block.cube.range import Range
from ..world.chunk.block_registry import BlockRegistry
from ..world.chunk.chunk import Chunk
from ..world.chunk.encode import encode_biomes, encode_sub_chunk
from ..world.chunk.encoding import NetworkEncoding
from ..world.position import ChunkPos, SubChunkPos


def network_chunk(pos: ChunkPos, dimension: Int32, c: Chunk) -> LevelChunk:
    """Builds the `LevelChunk` Dragonfly sends to a client without the blob
    cache (Go `sendNetworkChunk` with sub-chunk requests).

    Args:
        pos: The position of the chunk.
        dimension: The dimension ID.
        c: The chunk.

    Returns:
        The packet: no sub-chunks, a sub-chunk limit of
        `highest_filled_sub_chunk()`, and the biomes followed by a zero
        border block count as payload.
    """
    var pk = LevelChunk()
    pk.dimension = dimension
    pk.sub_chunk_count = 0
    pk.position = ProtocolChunkPos()
    pk.position.x = pos.x()
    pk.position.z = pos.z()
    pk.sub_chunk_limit = Int32(c.highest_filled_sub_chunk())
    pk.raw_payload = encode_biomes(c, NetworkEncoding())
    pk.raw_payload.append(0)
    return pk^


def sub_chunk_index(
    centre: SubChunkPos, offset: SubChunkOffset, r: Range
) -> Optional[Int16]:
    """Returns the index of the sub-chunk a request offset points at (from
    Go `ViewSubChunks`).

    Args:
        centre: The centre sub-chunk of the request.
        offset: One requested offset.
        r: The vertical range of the dimension.

    Returns:
        The sub-chunk index, or None if it is outside the range (Go answers
        `SubChunkResultIndexOutOfBounds`).
    """
    var ind = Int16(centre.y()) + Int16(offset.y) - (Int16(r.min()) >> 4)
    if ind < 0 or ind > Int16(r.height() >> 4):
        return None
    return ind


def sub_chunk_entry[
    R: BlockRegistry
](offset: SubChunkOffset, ind: Int16, mut col: Chunk, br: R) -> SubChunkEntry:
    """Builds the `SubChunk` entry for one sub-chunk of a loaded chunk (Go
    `subChunkEntry`, without the blob cache).

    Args:
        offset: The requested offset, echoed in the entry.
        ind: The index of the sub-chunk in the chunk.
        col: The chunk; its height map is recalculated if needed.
        br: The registry, for the height map.

    Parameters:
        R: The registry type.

    Returns:
        The entry with the height map relative to the sub-chunk and the
        network-encoded sub-chunk, or an all-air result.
    """
    var chunk_map = col.height_map(br)
    var sub_map_type = HEIGHT_MAP_DATA_HAS_DATA
    var sub_map = ProtocolHeightMap()
    var higher = True
    var lower = True
    for z in range(16):
        for x in range(16):
            var y = chunk_map.at(UInt8(x), UInt8(z))
            var other_ind = col.sub_index(y)
            if other_ind > ind:
                sub_map[z, x] = 16
                lower = False
            elif other_ind < ind:
                sub_map[z, x] = -1
                higher = False
            else:
                sub_map[z, x] = Int8(y - col.sub_y(other_ind))
                lower = False
                higher = False
    var entry = SubChunkEntry()
    entry.offset = offset
    if higher:
        sub_map_type = HEIGHT_MAP_DATA_TOO_HIGH
    elif lower:
        sub_map_type = HEIGHT_MAP_DATA_TOO_LOW
    else:
        entry.height_map_data = sub_map.copy()
        entry.render_height_map_data = sub_map^
    entry.height_map_type = sub_map_type
    entry.render_height_map_type = sub_map_type

    if col.sub()[Int(ind)].empty():
        entry.result = SUB_CHUNK_RESULT_SUCCESS_ALL_AIR
        return entry^
    entry.result = SUB_CHUNK_RESULT_SUCCESS
    entry.raw_payload = encode_sub_chunk(col, NetworkEncoding(), Int(ind))
    return entry^
