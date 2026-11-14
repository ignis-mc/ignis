"""Block compression of sorted tables, after goleveldb `table/writer.go`
`writeBlock` and `table/reader.go` `readRawBlock`.

Block type bytes are those of Mojang's LevelDB fork: 0 none, 1 snappy,
2 zlib (RFC 1950 header and Adler-32 trailer) and 4 raw DEFLATE. df-mc's
goleveldb reads and writes 0, 1 and 4 (and writes 4 by default); vanilla
Bedrock writes 4 and older worlds may hold 2, which this module reads and
writes too. DEFLATE and snappy come from the protocol submodule.
"""

from minecraft.internal.flate import deflate, inflate
from minecraft.internal.snappy import snappy_decode, snappy_encode

comptime NO_COMPRESSION: UInt8 = 0
"""Block type of an uncompressed block."""
comptime SNAPPY_COMPRESSION: UInt8 = 1
"""Block type of a snappy block."""
comptime ZLIB_COMPRESSION: UInt8 = 2
"""Block type of a zlib block (Mojang `ZlibCompressor`)."""
comptime FLATE_COMPRESSION: UInt8 = 4
"""Block type of a raw DEFLATE block (Mojang `ZlibCompressorRaw`, goleveldb
`FlateCompression`)."""

comptime FLATE_LEVEL = 5
"""The DEFLATE level goleveldb's table writer uses."""
comptime MAX_BLOCK_LEN = 64 * 1024 * 1024
"""The largest decompressed block accepted."""


def adler32(data: Span[mut=False, UInt8, _]) -> UInt32:
    """Computes the Adler-32 checksum (RFC 1950)."""
    comptime MOD = UInt32(65521)
    var a = UInt32(1)
    var b = UInt32(0)
    var i = 0
    while i < len(data):
        var end = min(i + 5552, len(data))
        while i < end:
            a += UInt32(data[i])
            b += a
            i += 1
        a %= MOD
        b %= MOD
    return (b << 16) | a


def compress(
    data: Span[mut=False, UInt8, _], kind: UInt8
) raises -> List[UInt8]:
    """Compresses a block with the given block type."""
    if kind == NO_COMPRESSION:
        return List[UInt8](data)
    if kind == SNAPPY_COMPRESSION:
        return snappy_encode(data)
    if kind == FLATE_COMPRESSION:
        return deflate(data, FLATE_LEVEL)
    if kind == ZLIB_COMPRESSION:
        var body = deflate(data, FLATE_LEVEL)
        var out = List[UInt8](capacity=len(body) + 6)
        # CMF: deflate, 32 KiB window; FLG: default level, check bits.
        out.append(0x78)
        out.append(0x9C)
        out.extend(Span(body))
        var a = adler32(data)
        out.append(UInt8(a >> 24))
        out.append(UInt8((a >> 16) & 0xFF))
        out.append(UInt8((a >> 8) & 0xFF))
        out.append(UInt8(a & 0xFF))
        return out^
    raise Error(t"leveldb: unknown compression type {kind}")


def decompress(
    data: Span[mut=False, UInt8, _], kind: UInt8
) raises -> List[UInt8]:
    """Decompresses a block of the given block type."""
    if kind == NO_COMPRESSION:
        return List[UInt8](data)
    if kind == SNAPPY_COMPRESSION:
        return snappy_decode(data, MAX_BLOCK_LEN)
    if kind == FLATE_COMPRESSION:
        return inflate(data, MAX_BLOCK_LEN)
    if kind == ZLIB_COMPRESSION:
        if len(data) < 6:
            raise Error("leveldb: zlib block too short")
        var cmf = data[0]
        var flg = data[1]
        if cmf & 0x0F != 8 or (UInt16(cmf) * 256 + UInt16(flg)) % 31 != 0:
            raise Error("leveldb: invalid zlib header")
        if flg & 0x20 != 0:
            raise Error("leveldb: zlib preset dictionary not supported")
        var out = inflate(data[2:], MAX_BLOCK_LEN)
        # The trailer follows the DEFLATE stream; inflate ignores trailing
        # bytes, so the last four bytes are the checksum.
        var n = len(data)
        var want = (
            (UInt32(data[n - 4]) << 24)
            | (UInt32(data[n - 3]) << 16)
            | (UInt32(data[n - 2]) << 8)
            | UInt32(data[n - 1])
        )
        if adler32(Span(out)) != want:
            raise Error("leveldb: zlib checksum mismatch")
        return out^
    raise Error(t"leveldb: unknown compression type {kind}")
