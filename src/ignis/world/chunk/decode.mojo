"""Chunk decoding, ported from Dragonfly `server/world/chunk/decode.go`.

`network_decode` reads `LevelChunk` payloads and `disk_decode` the
sub-chunk and biome values a world provider stores.

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
from minecraft.nbt.decode import decode_from
from minecraft.nbt.nbt import LITTLE_ENDIAN

from .conversion import Upgrades
from .encode import SerialisedData
from .encoding import Encoding, NetworkEncoding, decode_disk_block_state
from .palette import Palette, uint32s
from .paletted_storage import PalettedStorage
from .sub_chunk import SubChunk


def _valid_size(size: UInt8) -> Bool:
    return size <= 6 or size == 8 or size == 16


def network_decode[
    R: BlockRegistry
](br: R, data: Span[UInt8, _], count: Int, r: Range) raises -> Chunk:
    """Decodes network-encoded sub-chunks followed by biomes (Go
    `NetworkDecode`)."""
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
    """Decodes one sub-chunk of version 1, 8 or 9 (Go `decodeSubChunk`)."""
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
    """Decodes one paletted storage (Go `decodePalettedStorage`)."""
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


def disk_decode[
    R: BlockRegistry
](br: R, up: Upgrades, data: SerialisedData, r: Range) raises -> Chunk:
    """Decodes stored sub-chunks and biomes into a chunk (Go `DiskDecode`).

    Sub-chunks with no data stay empty. If a stored block state was older
    than the current version or lacked properties, the chunk is marked as
    having legacy states (Go `MarkLegacyStates` via the palette decoder).
    """
    var c = Chunk(br, r)
    var bpos = 0
    if len(data.biomes) != 0:
        for i in range(len(c._sub)):
            var b = _disk_decode_storage[False](
                br, up, Span(data.biomes), bpos, c
            )
            if b:
                c._biomes[i] = b.take()
            elif i == 0:
                raise Error("first biome storage pointed to previous one")
            else:
                c._biomes[i] = c._biomes[i - 1].copy()
    for i in range(min(len(data.sub_chunks), len(c._sub))):
        if len(data.sub_chunks[i]) == 0:
            continue
        var index = UInt8(i)
        var pos = 0
        var sub = disk_decode_sub_chunk(
            br, up, Span(data.sub_chunks[i]), pos, c, index
        )
        # Go stores the sub-chunk at the index of the key it was read from
        # and ignores the Y written inside version 9 data.
        c._sub[i] = sub^
    return c^


def disk_decode_sub_chunk[
    R: BlockRegistry
](
    br: R,
    up: Upgrades,
    data: Span[UInt8, _],
    mut pos: Int,
    mut c: Chunk,
    mut index: UInt8,
) raises -> SubChunk:
    """Decodes one stored sub-chunk of version 1, 8 or 9 (Go
    `decodeSubChunk` with `DiskEncoding`)."""
    if pos >= len(data):
        raise Error("error reading version: unexpected end of data")
    var ver = data[pos]
    pos += 1
    var sub = SubChunk(c._air)
    var count = 1
    if ver == 8 or ver == 9:
        if pos >= len(data):
            raise Error("error reading storage count: unexpected end of data")
        count = Int(data[pos])
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
    elif ver != 1:
        raise Error(t"unknown sub chunk version {ver}: can't decode")
    for _ in range(count):
        var storage = _disk_decode_storage[True](br, up, data, pos, c)
        if not storage:
            raise Error("sub-chunk storage pointed to previous one")
        sub._storages.append(storage.take())
    return sub^


def _disk_decode_storage[
    blocks: Bool, R: BlockRegistry
](
    br: R, up: Upgrades, data: Span[UInt8, _], mut pos: Int, mut c: Chunk
) raises -> Optional[PalettedStorage]:
    # Go decodePalettedStorage + diskEncoding.decodePalette.
    if pos >= len(data):
        raise Error("error reading block size: unexpected end of data")
    var block_size = data[pos] >> 1
    pos += 1
    if block_size == 0x7F:
        return None
    if not _valid_size(block_size):
        raise Error(t"cannot read paletted storage (size={block_size})")
    var n = uint32s(block_size)
    if len(data) - pos < n * 4:
        raise Error(
            t"cannot read paletted storage (size={block_size}): not enough"
            t" block data present: expected {n * 4} bytes, got"
            t" {len(data) - pos}"
        )
    var words = List[UInt32](capacity=n)
    for i in range(n):
        var o = pos + i * 4
        words.append(
            UInt32(data[o])
            | (UInt32(data[o + 1]) << 8)
            | (UInt32(data[o + 2]) << 16)
            | (UInt32(data[o + 3]) << 24)
        )
    pos += n * 4
    var count = 1
    if block_size != 0:
        if len(data) - pos < 4:
            raise Error(
                "error reading palette entry count: unexpected end of data"
            )
        count = Int(
            UInt32(data[pos])
            | (UInt32(data[pos + 1]) << 8)
            | (UInt32(data[pos + 2]) << 16)
            | (UInt32(data[pos + 3]) << 24)
        )
        pos += 4
    if count == 0:
        raise Error(
            t"invalid palette entry count: found 0, but palette with"
            t" {block_size} bits per block must have at least 1 value"
        )
    if count > len(data) - pos:
        raise Error(t"palette entry count {count} exceeds the data")
    var values = List[UInt32](capacity=count)
    for _ in range(count):
        comptime if blocks:
            var t = decode_from(data, pos, LITTLE_ENDIAN)
            var legacy = c._legacy_states
            values.append(decode_disk_block_state(br, up, t, t.root(), legacy))
            c._legacy_states = legacy
        else:
            if len(data) - pos < 4:
                raise Error(
                    "error decoding biome palette entry: unexpected end of data"
                )
            values.append(
                UInt32(data[pos])
                | (UInt32(data[pos + 1]) << 8)
                | (UInt32(data[pos + 2]) << 16)
                | (UInt32(data[pos + 3]) << 24)
            )
            pos += 4
    var storage = PalettedStorage(words^, Palette(block_size, values^))
    if block_size != 0:
        var m = UInt16(len(storage._palette))
        for x in range(16):
            for y in range(16):
                for z in range(16):
                    if (
                        storage._palette_index(UInt8(x), UInt8(y), UInt8(z))
                        >= m
                    ):
                        raise Error(
                            "paletted storage index points past the palette"
                        )
    return storage^
