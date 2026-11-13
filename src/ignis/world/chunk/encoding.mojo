"""Chunk encodings, ported from Dragonfly `server/world/chunk/encoding.go`.

`NetworkEncoding` is the generic `Encoding` used by `encode`. The disk
encoding needs the block registry and the upgrade data while it runs, so
instead of a stateless `Encoding` it is a set of functions: block palettes
are little-endian NBT `{name, states, version}` entries
(`encode_disk_block_state`, `decode_disk_block_state`, Go
`BlockPaletteEncoding`), biome palettes little-endian uint32s (Go
`biomePaletteEncoding`), both preceded by a uint32 count unless the storage
uses 0 bits per index (Go `diskEncoding`). `encode.disk_encode` and
`decode.disk_decode` use them.

Differences from Go: properties of an encoded state are written in key
order (Go iterates a map, so its order varies between runs); a palette
count larger than the remaining data is rejected before allocating.
"""

from minecraft.nbt.nbt import TAG_BYTE, TAG_COMPOUND, TAG_INT, TAG_STRING
from minecraft.nbt.tree import Tag, Tree

from ..block_state import BlockState, Properties, PropertyValue
from .block_registry import BlockRegistry
from .conversion import Upgrades
from .encode import CURRENT_BLOCK_VERSION
from .palette import Palette

comptime _PRE_FLATTENING_VERSION: Int32 = 17694723


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


def encode_disk_block_state[
    R: BlockRegistry
](br: R, v: UInt32, mut t: Tree, root: Tag) raises:
    """Writes the state of a runtime ID into a compound as `name`, `states`
    and `version` (Go `BlockPaletteEncoding.EncodeBlockState`).

    Parameters:
        R: The registry type.

    Args:
        br: The registry.
        v: The runtime ID.
        t: The tree to write into.
        root: The compound to fill.

    Raises:
        If the tree rejects a value.
    """
    var name = String()
    var props = Properties()
    if case .Some(s) = br.runtime_id_to_state(v):
        name = s.name
        props = s.properties.copy()
    _ = t.put_string(root, "name", name)
    var states = t.put_compound(root, "states")
    for ref p in props.entries:
        if p.value.tag == TAG_STRING:
            _ = t.put_string(states, p.key, p.value.string)
        elif p.value.tag == TAG_INT:
            _ = t.put_int(states, p.key, p.value.int)
        else:
            _ = t.put_byte(states, p.key, UInt8(p.value.int))
    _ = t.put_int(root, "version", CURRENT_BLOCK_VERSION)


def _fill_defaults[
    R: BlockRegistry
](br: R, name: StringSlice, properties: Properties) -> Tuple[Properties, Bool]:
    # Go BlockPaletteEncoding.fillDefaults.
    var filled = False
    var out = properties.copy()
    if case .Some(defaults) = br.default_properties(name):
        for ref p in defaults.entries:
            if not out.get(p.key):
                out.set(p.key, p.value.copy())
                filled = True
    return (out^, filled)


def decode_disk_block_state[
    R: BlockRegistry
](br: R, up: Upgrades, t: Tree, m: Tag, mut legacy: Bool) raises -> UInt32:
    """Reads a stored block state and returns its runtime ID (Go
    `BlockPaletteEncoding.DecodeBlockState`): pre-1.13 entries (`val`) are
    mapped through `legacy_states.nbt`, newer ones upgraded by the schemas,
    and properties the state lacks are filled from the block's default.

    Parameters:
        R: The registry type.

    Args:
        br: The registry.
        up: The upgrade data.
        t: The tree holding the entry.
        m: The `{name, states, version}` compound.
        legacy: Set to True if the entry is older than
            `CURRENT_BLOCK_VERSION` or properties were added to it; derived
            properties may then hold defaults (Go's `legacy` flag).

    Returns:
        The runtime ID.

    Raises:
        If the entry is malformed or names an unknown state.
    """
    var name = String()
    if case .Some(n) = t.get(m, "name"):
        if t.type_of(n) == TAG_STRING:
            name = t.as_string(n)
    var version = Int32(0)
    if case .Some(n) = t.get(m, "version"):
        if t.type_of(n) == TAG_INT:
            version = t.as_int(n)
    var state = Properties()
    if version < _PRE_FLATTENING_VERSION:
        var meta = Int16(0)
        if case .Some(n) = t.get(m, "val"):
            if t.type_of(n) == 2:
                meta = t.as_short(n)
        var entry = up.upgrade_legacy_entry(name, meta)
        if not entry:
            raise Error(
                t"cannot find mapping for legacy block entry: {name}, {meta}"
            )
        name = entry.value().name
        state = entry.value().properties.copy()
        version = entry.value().version
    elif case .Some(st) = t.get(m, "states"):
        if t.type_of(st) != TAG_COMPOUND:
            raise Error("invalid state in block entry")
        for c in t.children(st):
            var ty = t.type_of(c)
            if ty == TAG_BYTE:
                state.set(t.name(c), PropertyValue(byte=t.as_byte(c)))
            elif ty == TAG_INT:
                state.set(t.name(c), PropertyValue(int32=t.as_int(c)))
            elif ty == TAG_STRING:
                state.set(t.name(c), PropertyValue(string=t.as_string(c)))
            else:
                raise Error(
                    t"block state {name}: property {t.name(c)} has tag {ty}"
                )
    var stored = len(state)
    var upgraded = up.blocks.upgrade(BlockState(name, state^, version))
    var filled = _fill_defaults(br, upgraded.name, upgraded.properties)
    if (
        version < CURRENT_BLOCK_VERSION
        or len(upgraded.properties) > stored
        or filled[1]
    ):
        legacy = True
    if case .Some(v) = br.state_to_runtime_id(upgraded.name, filled[0]):
        return v
    raise Error(
        t"cannot get runtime ID of block state {upgraded.name}{{{filled[0]}}}"
        t" {upgraded.version}"
    )
