"""Varints, little-endian helpers, LevelDB's hash and its masked CRC-32C,
ported from goleveldb `util/hash.go` and `util/crc32.go`."""

from nethernet.crypto.crc import crc32c


def put_uvarint(mut out: List[UInt8], x: UInt64):
    """Appends an unsigned LEB128 varint (Go `binary.PutUvarint`).

    Args:
        out: The destination.
        x: The value.
    """
    var v = x
    while v >= 0x80:
        out.append(UInt8(v & 0x7F) | 0x80)
        v >>= 7
    out.append(UInt8(v))


def read_uvarint(data: Span[UInt8, _], mut pos: Int) raises -> UInt64:
    """Reads an unsigned varint (Go `binary.Uvarint`).

    Args:
        data: The input.
        pos: The offset; advanced past the varint.

    Returns:
        The value.

    Raises:
        If the input ends early or the varint overflows 64 bits.
    """
    var x = UInt64(0)
    var shift = UInt64(0)
    for i in range(10):
        if pos >= len(data):
            raise Error("leveldb: truncated varint")
        var b = data[pos]
        pos += 1
        if b < 0x80:
            if i == 9 and b > 1:
                raise Error("leveldb: varint overflows 64 bits")
            return x | (UInt64(b) << shift)
        x |= UInt64(b & 0x7F) << shift
        shift += 7
    raise Error("leveldb: varint overflows 64 bits")


def read_varint_int(data: Span[UInt8, _], mut pos: Int) raises -> Int:
    """Reads an unsigned varint that must fit a non-negative `Int`.

    Args:
        data: The input.
        pos: The offset; advanced past the varint.

    Returns:
        The value.

    Raises:
        If the varint is malformed or too large.
    """
    var v = read_uvarint(data, pos)
    if v > UInt64(Int.MAX):
        raise Error("leveldb: varint out of range")
    return Int(v)


def put_u32(mut out: List[UInt8], x: UInt32):
    """Appends a little-endian uint32.

    Args:
        out: The destination.
        x: The value.
    """
    out.append(UInt8(x & 0xFF))
    out.append(UInt8((x >> 8) & 0xFF))
    out.append(UInt8((x >> 16) & 0xFF))
    out.append(UInt8(x >> 24))


def put_u64(mut out: List[UInt8], x: UInt64):
    """Appends a little-endian uint64.

    Args:
        out: The destination.
        x: The value.
    """
    for i in range(8):
        out.append(UInt8((x >> UInt64(8 * i)) & 0xFF))


def get_u32(data: Span[UInt8, _], pos: Int) -> UInt32:
    """Reads a little-endian uint32; the caller checks the bounds.

    Args:
        data: The input.
        pos: The offset.

    Returns:
        The value.
    """
    return (
        UInt32(data[pos])
        | (UInt32(data[pos + 1]) << 8)
        | (UInt32(data[pos + 2]) << 16)
        | (UInt32(data[pos + 3]) << 24)
    )


def get_u64(data: Span[UInt8, _], pos: Int) -> UInt64:
    """Reads a little-endian uint64; the caller checks the bounds.

    Args:
        data: The input.
        pos: The offset.

    Returns:
        The value.
    """
    var x = UInt64(0)
    for i in range(8):
        x |= UInt64(data[pos + i]) << UInt64(8 * i)
    return x


def masked_crc(data: Span[UInt8, _]) -> UInt32:
    """Returns LevelDB's masked CRC-32C of the data (Go `util.NewCRC(b).Value`).

    Args:
        data: The bytes.

    Returns:
        The masked checksum.
    """
    var c = crc32c(data)
    return ((c >> 15) | (c << 17)) + 0xA282EAD8


def hash(data: Span[UInt8, _], seed: UInt32) -> UInt32:
    """LevelDB's murmur-like hash with unsigned tail bytes (Go `util.Hash`).

    Args:
        data: The bytes.
        seed: The seed.

    Returns:
        The hash.
    """
    comptime m = UInt32(0xC6A4A793)
    var h = seed ^ (UInt32(len(data)) * m)
    var i = 0
    var n = len(data) - len(data) % 4
    while i < n:
        h += get_u32(data, i)
        h *= m
        h ^= h >> 16
        i += 4
    var rest = len(data) - i
    if rest == 3:
        h += UInt32(data[i + 2]) << 16
    if rest >= 2:
        h += UInt32(data[i + 1]) << 8
    if rest >= 1:
        h += UInt32(data[i])
        h *= m
        h ^= h >> 24
    return h


def hash_signed_tail(data: Span[UInt8, _], seed: UInt32) -> UInt32:
    """The same hash with tail bytes sign-extended, as C++ LevelDB computed it
    on `char`-signed platforms before 1.21. Filters written by such builds
    are only consistent with this variant.

    Args:
        data: The bytes.
        seed: The seed.

    Returns:
        The hash.
    """
    comptime m = UInt32(0xC6A4A793)
    var h = seed ^ (UInt32(len(data)) * m)
    var i = 0
    var n = len(data) - len(data) % 4
    while i < n:
        h += get_u32(data, i)
        h *= m
        h ^= h >> 16
        i += 4
    var rest = len(data) - i
    if rest == 3:
        h += UInt32(Int32(Int8(data[i + 2]))) << 16
    if rest >= 2:
        h += UInt32(Int32(Int8(data[i + 1]))) << 8
    if rest >= 1:
        h += UInt32(Int32(Int8(data[i])))
        h *= m
        h ^= h >> 24
    return h


def compare_bytes(a: Span[UInt8, _], b: Span[UInt8, _]) -> Int:
    """Compares two byte strings lexicographically (Go `bytes.Compare`).

    Args:
        a: The first string.
        b: The second string.

    Returns:
        -1, 0 or 1.
    """
    var n = min(len(a), len(b))
    for i in range(n):
        if a[i] != b[i]:
            return -1 if a[i] < b[i] else 1
    if len(a) == len(b):
        return 0
    return -1 if len(a) < len(b) else 1
