"""Chunk decoding, ported from the network half of Dragonfly
`server/world/chunk/decode.go`.

Disk decoding comes with the disk encoding; see `encoding.mojo`.

Differences from Go, which trust the input more than network data deserves:

- Only the storage sizes the format defines (0, 1, 2, 3, 4, 5, 6, 8 and 16
  bits per index) are accepted. Go accepts any size up to 32, and a size
  such as 7 then builds a storage whose word count implies another size.
- Every index must point inside the palette; Go panics on the first lookup
  of an index past the end.
- A biome storage that repeats the previous one is a copy, not a second
  reference to the same storage.
"""

from ...block.cube.range import Range
from .block_registry import BlockRegistry
from .chunk import Chunk
from .encoding import Encoding, NetworkEncoding
from .palette import uint32s
from .paletted_storage import PalettedStorage
from .sub_chunk import SubChunk


def _valid_size(size: UInt8) -> Bool:
    return size <= 6 or size == 8 or size == 16


def network_decode[
    R: BlockRegistry
](br: R, data: Span[UInt8, _], count: Int, r: Range) raises -> Chunk:
    """Decodes network-encoded sub-chunks followed by biomes (Go
    `NetworkDecode`).

    Parameters:
        R: The registry type.

    Args:
        br: The finalized registry the runtime IDs belong to.
        data: The payload, as in a `LevelChunk` packet.
        count: The sub-chunk count from the `LevelChunk` packet.
        r: The vertical range of the chunk.

    Returns:
        The chunk.

    Raises:
        If the payload is malformed or does not fit the range.
    """
    var c = Chunk(br, r)
    if count < 0 or count > len(c._sub):
        raise Error(
            t"invalid sub-chunk count {count}: chunk range has"
            t" {len(c._sub)} sub-chunks"
        )
    var pos = 0
    for i in range(count):
        var index = UInt8(i)
        var sub = decode_sub_chunk[NetworkEncoding](data, pos, c, index)
        if Int(index) >= len(c._sub):
            raise Error(
                t"invalid sub-chunk index {index}: chunk range has"
                t" {len(c._sub)} sub-chunks"
            )
        c._sub[Int(index)] = sub^
    for i in range(len(c._sub)):
        var b = decode_paletted_storage[NetworkEncoding](data, pos)
        if b:
            c._biomes[i] = b.take()
        elif i == 0:
            raise Error("first biome storage pointed to previous one")
        else:
            c._biomes[i] = c._biomes[i - 1].copy()
    return c^


def decode_sub_chunk[
    E: Encoding
](
    data: Span[UInt8, _], mut pos: Int, c: Chunk, mut index: UInt8
) raises -> SubChunk:
    """Decodes one sub-chunk of version 1, 8 or 9 (Go `decodeSubChunk`).

    Parameters:
        E: The encoding.

    Args:
        data: The input.
        pos: The offset to read at; advanced past the sub-chunk.
        c: The chunk the sub-chunk belongs to (for air and the range).
        index: The expected index; version 9 replaces it with the index
            derived from the Y stored in the data.

    Returns:
        The sub-chunk.

    Raises:
        If the input is malformed.
    """
    if pos >= len(data):
        raise Error("error reading version: unexpected end of data")
    var ver = data[pos]
    pos += 1
    var sub = SubChunk(c._air)
    if ver == 1:
        var storage = decode_paletted_storage[E](data, pos)
        if not storage:
            raise Error("sub-chunk storage pointed to previous one")
        sub._storages.append(storage.take())
    elif ver == 8 or ver == 9:
        if pos >= len(data):
            raise Error("error reading storage count: unexpected end of data")
        var storage_count = Int(data[pos])
        pos += 1
        if ver == 9:
            if pos >= len(data):
                raise Error(
                    "error reading sub-chunk index: unexpected end of data"
                )
            var y = Int8(
                Int(data[pos]) - 256 if data[pos] >= 128 else Int(data[pos])
            )
            pos += 1
            index = UInt8(y - Int8(c._r.min() >> 4))
        for _ in range(storage_count):
            var storage = decode_paletted_storage[E](data, pos)
            if not storage:
                raise Error("sub-chunk storage pointed to previous one")
            sub._storages.append(storage.take())
    else:
        raise Error(t"unknown sub chunk version {ver}: can't decode")
    return sub^


def decode_paletted_storage[
    E: Encoding
](data: Span[UInt8, _], mut pos: Int) raises -> Optional[PalettedStorage]:
    """Decodes one paletted storage (Go `decodePalettedStorage`).

    Parameters:
        E: The encoding.

    Args:
        data: The input.
        pos: The offset to read at; advanced past the storage.

    Returns:
        The storage, or None if the header says "same as the previous
        storage".

    Raises:
        If the input is malformed.
    """
    if pos >= len(data):
        raise Error("error reading block size: unexpected end of data")
    var block_size = data[pos] >> 1
    pos += 1
    if block_size == 0x7F:
        return None
    if not _valid_size(block_size):
        raise Error(t"cannot read paletted storage (size={block_size})")
    var count = uint32s(block_size)
    if len(data) - pos < count * 4:
        raise Error(
            t"cannot read paletted storage (size={block_size}): not enough"
            t" block data present: expected {count * 4} bytes, got"
            t" {len(data) - pos}"
        )
    var words = List[UInt32](capacity=count)
    for i in range(count):
        var o = pos + i * 4
        words.append(
            UInt32(data[o])
            | (UInt32(data[o + 1]) << 8)
            | (UInt32(data[o + 2]) << 16)
            | (UInt32(data[o + 3]) << 24)
        )
    pos += count * 4
    var palette = E.decode_palette(data, pos, block_size)
    var storage = PalettedStorage(words^, palette^)
    if block_size != 0:
        var n = UInt16(len(storage._palette))
        for x in range(16):
            for y in range(16):
                for z in range(16):
                    if (
                        storage._palette_index(UInt8(x), UInt8(y), UInt8(z))
                        >= n
                    ):
                        raise Error(
                            "paletted storage index points past the palette"
                        )
    return storage^
