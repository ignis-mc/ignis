"""Chunk encoding, ported from Dragonfly `server/world/chunk/encode.go`."""

from minecraft.nbt.encode import encode_to
from minecraft.nbt.nbt import LITTLE_ENDIAN
from minecraft.nbt.tree import Tree

from .block_registry import BlockRegistry
from .chunk import Chunk
from .encoding import Encoding, encode_disk_block_state
from .paletted_storage import PalettedStorage

comptime SUB_CHUNK_VERSION: UInt8 = 9
"""The version of written sub-chunks, on disk and over the network."""

comptime CURRENT_BLOCK_VERSION: Int32 = 18168865
"""The block state version of the game: 1.21.60.33 as big-endian bytes."""


struct SerialisedData(Copyable, Movable):
    """The encoded blocks and biomes of a chunk."""

    var sub_chunks: List[List[UInt8]]
    """One encoded sub-chunk per sub-chunk, lowest first."""
    var biomes: List[UInt8]
    """The biome storages of every sub-chunk, concatenated."""

    def __init__(out self):
        """Creates empty data."""
        self.sub_chunks = List[List[UInt8]]()
        self.biomes = List[UInt8]()


def encode[E: Encoding](c: Chunk, e: E) -> SerialisedData:
    """Encodes every sub-chunk and the biomes of a chunk (Go `Encode`).

    Parameters:
        E: The encoding type.

    Args:
        c: The chunk.
        e: The encoding, such as `NetworkEncoding()`.

    Returns:
        The encoded data.
    """
    var d = SerialisedData()
    for i in range(len(c._sub)):
        d.sub_chunks.append(encode_sub_chunk(c, e, i))
    d.biomes = encode_biomes(c, e)
    return d^


def encode_sub_chunk[E: Encoding](c: Chunk, e: E, ind: Int) -> List[UInt8]:
    """Encodes one sub-chunk (Go `EncodeSubChunk`): version 9, the layer
    count, the absolute sub-chunk Y, then each layer.

    Parameters:
        E: The encoding type.

    Args:
        c: The chunk.
        e: The encoding.
        ind: The index of the sub-chunk.

    Returns:
        The encoded sub-chunk.
    """
    ref s = c._sub[ind]
    var buf = List[UInt8](capacity=1024)
    buf.append(SUB_CHUNK_VERSION)
    buf.append(UInt8(len(s._storages)))
    buf.append(UInt8((ind + (c._r.min() >> 4)) & 0xFF))
    for i in range(len(s._storages)):
        _encode_paletted_storage(buf, s._storages[i], e)
    return buf^


def encode_biomes[E: Encoding](c: Chunk, e: E) -> List[UInt8]:
    """Encodes the biome storages of a chunk (Go `EncodeBiomes`). A storage
    equal to the previous one is written as the single byte `0xff`.

    Parameters:
        E: The encoding type.

    Args:
        c: The chunk.
        e: The encoding.

    Returns:
        The encoded biomes.
    """
    var buf = List[UInt8](capacity=1024)
    for i in range(len(c._biomes)):
        if i > 0 and c._biomes[i].equal(c._biomes[i - 1]):
            buf.append((0x7F << 1) | E.network())
            continue
        _encode_paletted_storage(buf, c._biomes[i], e)
    return buf^


def _encode_paletted_storage[
    E: Encoding
](mut buf: List[UInt8], storage: PalettedStorage, e: E):
    buf.append(UInt8(storage._bits_per_index << 1) | E.network())
    for v in storage._indices:
        buf.append(UInt8(v & 0xFF))
        buf.append(UInt8((v >> 8) & 0xFF))
        buf.append(UInt8((v >> 16) & 0xFF))
        buf.append(UInt8((v >> 24) & 0xFF))
    E.encode_palette(buf, storage._palette)


def _encode_storage_words(
    mut buf: List[UInt8], storage: PalettedStorage, network: UInt8
):
    buf.append(UInt8(storage._bits_per_index << 1) | network)
    for v in storage._indices:
        buf.append(UInt8(v & 0xFF))
        buf.append(UInt8((v >> 8) & 0xFF))
        buf.append(UInt8((v >> 16) & 0xFF))
        buf.append(UInt8((v >> 24) & 0xFF))


def _put_u32(mut buf: List[UInt8], v: UInt32):
    buf.append(UInt8(v & 0xFF))
    buf.append(UInt8((v >> 8) & 0xFF))
    buf.append(UInt8((v >> 16) & 0xFF))
    buf.append(UInt8(v >> 24))


def disk_encode[R: BlockRegistry](c: Chunk, br: R) raises -> SerialisedData:
    """Encodes every sub-chunk and the biomes of a chunk for disk (Go
    `Encode(c, DiskEncoding)`).

    Parameters:
        R: The registry type.

    Args:
        c: The chunk.
        br: The registry the chunk's runtime IDs belong to.

    Returns:
        The encoded data.

    Raises:
        If a palette entry cannot be encoded.
    """
    var d = SerialisedData()
    for i in range(len(c._sub)):
        d.sub_chunks.append(disk_encode_sub_chunk(c, br, i))
    d.biomes = disk_encode_biomes(c)
    return d^


def disk_encode_sub_chunk[
    R: BlockRegistry
](c: Chunk, br: R, ind: Int) raises -> List[UInt8]:
    """Encodes one sub-chunk for disk (Go `EncodeSubChunk(c, DiskEncoding,
    ind)`): version 9, the layer count, the sub-chunk Y, then each layer
    with an NBT block palette.

    Parameters:
        R: The registry type.

    Args:
        c: The chunk.
        br: The registry.
        ind: The index of the sub-chunk.

    Returns:
        The encoded sub-chunk.

    Raises:
        If a palette entry cannot be encoded.
    """
    ref s = c._sub[ind]
    var buf = List[UInt8](capacity=1024)
    buf.append(SUB_CHUNK_VERSION)
    buf.append(UInt8(len(s._storages)))
    buf.append(UInt8((ind + (c._r.min() >> 4)) & 0xFF))
    for i in range(len(s._storages)):
        ref storage = s._storages[i]
        _encode_storage_words(buf, storage, 0)
        ref p = storage._palette
        if p._size != 0:
            _put_u32(buf, UInt32(len(p)))
        for v in p._values:
            var t = Tree()
            encode_disk_block_state(br, v, t, t.root())
            encode_to(t, LITTLE_ENDIAN, buf)
    return buf^


def disk_encode_biomes(c: Chunk) -> List[UInt8]:
    """Encodes the biome storages of a chunk for disk (Go
    `EncodeBiomes(c, DiskEncoding)`): uint32 palettes, `0xfe` for a storage
    equal to the previous one.

    Args:
        c: The chunk.

    Returns:
        The encoded biomes.
    """
    var buf = List[UInt8](capacity=1024)
    for i in range(len(c._biomes)):
        if i > 0 and c._biomes[i].equal(c._biomes[i - 1]):
            buf.append(0x7F << 1)
            continue
        ref storage = c._biomes[i]
        _encode_storage_words(buf, storage, 0)
        ref p = storage._palette
        if p._size != 0:
            _put_u32(buf, UInt32(len(p)))
        for v in p._values:
            _put_u32(buf, v)
    return buf^
