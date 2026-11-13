"""Chunk encodings, ported from Dragonfly `server/world/chunk/encoding.go`.

Only `NetworkEncoding` is ported. The disk encoding writes palettes as NBT
block states and its decoder upgrades old states through
`df-mc/worldupgrader`; it comes with the world provider (Ignis worlds are
generated in memory for now).
"""

from .palette import Palette


def put_varint32(mut buf: List[UInt8], x: Int32):
    """Appends a zigzag varint32 (gophertunnel `protocol.WriteVarint32`).

    Args:
        buf: The destination.
        x: The value.
    """
    var u = (UInt32(x) << 1) ^ UInt32(x >> 31)
    while u >= 0x80:
        buf.append(UInt8(u & 0x7F) | 0x80)
        u >>= 7
    buf.append(UInt8(u))


def read_varint32(data: Span[UInt8, _], mut pos: Int) raises -> Int32:
    """Reads a zigzag varint32 (gophertunnel `protocol.Varint32`).

    Args:
        data: The input.
        pos: The offset to read at; advanced past the value.

    Returns:
        The value.

    Raises:
        If the input ends early or the varint is longer than 5 bytes.
    """
    var u = UInt32(0)
    for i in range(5):
        if pos >= len(data):
            raise Error("varint32: unexpected end of data")
        var b = data[pos]
        pos += 1
        u |= UInt32(b & 0x7F) << UInt32(7 * i)
        if b & 0x80 == 0:
            return Int32(u >> 1) ^ -Int32(u & 1)
    raise Error("varint32: did not terminate after 5 bytes")


trait Encoding:
    """How a chunk's palettes are written (Go `Encoding`)."""

    @staticmethod
    def network() -> UInt8:
        """Returns the low bit of each storage header: 1 for network.

        Returns:
            0 or 1.
        """
        ...

    @staticmethod
    def encode_palette(mut buf: List[UInt8], p: Palette):
        """Appends a palette.

        Args:
            buf: The destination.
            p: The palette.
        """
        ...

    @staticmethod
    def decode_palette(
        data: Span[UInt8, _], mut pos: Int, block_size: UInt8
    ) raises -> Palette:
        """Reads a palette.

        Args:
            data: The input.
            pos: The offset to read at; advanced past the palette.
            block_size: The bits per index of the storage.

        Returns:
            The palette.

        Raises:
            If the input is malformed.
        """
        ...


@fieldwise_init
struct NetworkEncoding(Encoding, ImplicitlyCopyable):
    """The encoding for sending chunks: varint palettes of runtime IDs, no
    NBT (Go `NetworkEncoding`)."""

    @staticmethod
    def network() -> UInt8:
        """Returns 1, the network flag of storage headers.

        Returns:
            1.
        """
        return 1

    @staticmethod
    def encode_palette(mut buf: List[UInt8], p: Palette):
        """Appends the palette length (unless 0 bits per index) and each
        value as varint32s.

        Args:
            buf: The destination.
            p: The palette.
        """
        if p._size != 0:
            put_varint32(buf, Int32(len(p)))
        for v in p._values:
            put_varint32(buf, Int32(v))

    @staticmethod
    def decode_palette(
        data: Span[UInt8, _], mut pos: Int, block_size: UInt8
    ) raises -> Palette:
        """Reads a palette written by `encode_palette`.

        Args:
            data: The input.
            pos: The offset to read at; advanced past the palette.
            block_size: The bits per index of the storage.

        Returns:
            The palette.

        Raises:
            If the input ends early or the count is not positive.
        """
        var count = Int32(1)
        if block_size != 0:
            count = read_varint32(data, pos)
            if count <= 0:
                raise Error(t"invalid palette entry count {count}")
            if Int(count) > len(data) - pos:
                raise Error(t"palette entry count {count} exceeds the data")
        var values = List[UInt32](capacity=Int(count))
        for _ in range(Int(count)):
            values.append(UInt32(read_varint32(data, pos)))
        return Palette(block_size, values^)
