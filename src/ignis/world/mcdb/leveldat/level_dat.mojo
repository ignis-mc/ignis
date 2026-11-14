"""The `level.dat` file container, ported from Dragonfly
`server/world/mcdb/leveldat/level_dat.go`.

A `level.dat` is an 8-byte header (storage version and payload length,
both little-endian int32) followed by a little-endian NBT compound.
"""

from minecraft.nbt.decode import decode
from minecraft.nbt.encode import encode
from minecraft.nbt.nbt import LITTLE_ENDIAN
from minecraft.nbt.tree import Tree

from ....internal.fs import read_file, write_file
from .data import Data
from .version import VERSION


def _i32(b: Span[UInt8, _], o: Int) -> Int32:
    return Int32(
        UInt32(b[o])
        | (UInt32(b[o + 1]) << 8)
        | (UInt32(b[o + 2]) << 16)
        | (UInt32(b[o + 3]) << 24)
    )


def _put_i32(mut out: List[UInt8], v: Int32):
    var u = UInt32(v)
    for i in range(4):
        out.append(UInt8((u >> UInt32(8 * i)) & 0xFF))


struct LevelDat(Movable):
    """A `level.dat`: header and NBT payload (Go `LevelDat`)."""

    var storage_version: Int32
    """The storage version from the header."""
    var data: List[UInt8]
    """The little-endian NBT payload."""

    def __init__(out self):
        """Creates an empty `level.dat` (Go's zero value)."""
        self.storage_version = 0
        self.data = List[UInt8]()

    @staticmethod
    def read(b: Span[UInt8, _]) raises -> LevelDat:
        """Parses a `level.dat` (Go `Read`)."""
        if len(b) < 8:
            raise Error("level.dat: read header: unexpected end of data")
        var n = _i32(b, 4)
        if n < 0 or Int(n) > len(b) - 8:
            raise Error("level.dat: read data: unexpected end of data")
        var l = LevelDat()
        l.storage_version = _i32(b, 0)
        l.data = List[UInt8](b[8 : 8 + Int(n)])
        return l^

    @staticmethod
    def read_file(path: StringSlice) raises -> LevelDat:
        """Reads a `level.dat` from disk (Go `ReadFile`)."""
        var b = read_file(path)
        return LevelDat.read(Span(b))

    def ver(self) -> Int:
        """Returns the storage version (Go `Ver`)."""
        return Int(self.storage_version)

    def unmarshal(self) raises -> Data:
        """Decodes the payload (Go `Unmarshal` into `Data`)."""
        return Data.unmarshal(decode(Span(self.data), LITTLE_ENDIAN))

    def marshal(mut self, d: Data) raises:
        """Encodes data as the payload and sets the current storage version
        (Go `Marshal`)."""
        self.data = encode(d.marshal(), LITTLE_ENDIAN)
        self.storage_version = VERSION

    def bytes(self) -> List[UInt8]:
        """Returns the header followed by the payload (Go `Write`)."""
        var out = List[UInt8](capacity=8 + len(self.data))
        _put_i32(out, self.storage_version)
        _put_i32(out, Int32(len(self.data)))
        out.extend(Span(self.data))
        return out^

    def write_file(self, path: StringSlice) raises:
        """Writes the `level.dat` to disk, replacing it (Go `WriteFile`)."""
        write_file(path, Span(self.bytes()), sync=True)
