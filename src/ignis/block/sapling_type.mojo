"""`SaplingType`, ported from Dragonfly `server/block/sapling_type.go`."""

from ..internal.enum import enum_name
from .leaves_type import LeavesType
from .wood_type import WoodType


struct SaplingType(Equatable, ImplicitlyCopyable, Writable):
    """A type of sapling (Go `SaplingType`)."""

    var _v: UInt8

    comptime OAK = SaplingType(0)
    """Go `OakSapling()`."""
    comptime SPRUCE = SaplingType(1)
    """Go `SpruceSapling()`."""
    comptime BIRCH = SaplingType(2)
    """Go `BirchSapling()`."""
    comptime JUNGLE = SaplingType(3)
    """Go `JungleSapling()`."""
    comptime ACACIA = SaplingType(4)
    """Go `AcaciaSapling()`."""
    comptime DARK_OAK = SaplingType(5)
    """Go `DarkOakSapling()`."""
    comptime CHERRY = SaplingType(6)
    """Go `CherrySapling()`."""
    comptime PALE_OAK = SaplingType(7)
    """Go `PaleOakSapling()`."""
    comptime POPLAR = SaplingType(8)
    """Go `PoplarSapling()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `SaplingType{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`)."""
        return enum_name(
            (
                "Oak Sapling,Spruce Sapling,Birch Sapling,Jungle Sapling,"
                "Acacia Sapling,Dark Oak Sapling,Cherry Sapling,"
                "Pale Oak Sapling,Poplar Sapling"
            ),
            Int(self._v),
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`)."""
        writer.write(
            enum_name(
                (
                    "oak_sapling,spruce_sapling,birch_sapling,jungle_sapling,"
                    "acacia_sapling,dark_oak_sapling,cherry_sapling,"
                    "pale_oak_sapling,poplar_sapling"
                ),
                Int(self._v),
            )
        )

    def wood(self) -> WoodType:
        """Returns the wood of trees the sapling grows into (Go `Wood`)."""
        if self._v <= 5:
            return WoodType(Int(self._v))
        if self == SaplingType.CHERRY:
            return WoodType.CHERRY
        if self == SaplingType.PALE_OAK:
            return WoodType.PALE_OAK
        return WoodType.POPLAR

    def leaves(self) -> LeavesType:
        """Returns the leaves of trees the sapling grows into (Go `Leaves`)."""
        if self._v <= 5:
            return LeavesType(Int(self._v))
        if self == SaplingType.CHERRY:
            return LeavesType.CHERRY
        if self == SaplingType.PALE_OAK:
            return LeavesType.PALE_OAK
        return LeavesType.ORANGE_POPLAR


def sapling_types() -> List[SaplingType]:
    """Returns every sapling type (Go `SaplingTypes`)."""
    var out = List[SaplingType](capacity=9)
    for i in range(9):
        out.append(SaplingType(i))
    return out^
