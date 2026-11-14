"""`WoodType`, ported from Dragonfly `server/block/wood_type.go`."""

from ..internal.enum import enum_name
from .leaves_type import LeavesType


struct WoodType(Equatable, ImplicitlyCopyable, Writable):
    """A type of wood of a block, such as logs and planks (Go `WoodType`)."""

    var _wood: UInt8

    comptime OAK = WoodType(0)
    """Go `OakWood()`."""
    comptime SPRUCE = WoodType(1)
    """Go `SpruceWood()`."""
    comptime BIRCH = WoodType(2)
    """Go `BirchWood()`."""
    comptime JUNGLE = WoodType(3)
    """Go `JungleWood()`."""
    comptime ACACIA = WoodType(4)
    """Go `AcaciaWood()`."""
    comptime DARK_OAK = WoodType(5)
    """Go `DarkOakWood()`."""
    comptime CRIMSON = WoodType(6)
    """Go `CrimsonWood()`."""
    comptime WARPED = WoodType(7)
    """Go `WarpedWood()`."""
    comptime MANGROVE = WoodType(8)
    """Go `MangroveWood()`."""
    comptime CHERRY = WoodType(9)
    """Go `CherryWood()`."""
    comptime PALE_OAK = WoodType(10)
    """Go `PaleOakWood()`."""
    comptime BAMBOO = WoodType(11)
    """Go `BambooWood()`."""
    comptime POPLAR = WoodType(12)
    """Go `PoplarWood()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `WoodType{v}`)."""
        self._wood = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._wood == other._wood

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._wood

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`)."""
        return enum_name(
            (
                "Oak Wood,Spruce Wood,Birch Wood,Jungle Wood,Acacia Wood,"
                "Dark Oak Wood,Crimson Wood,Warped Wood,Mangrove Wood,"
                "Cherry Wood,Pale Oak Wood,Bamboo Wood,Poplar Wood"
            ),
            Int(self._wood),
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`)."""
        writer.write(
            enum_name(
                (
                    "oak,spruce,birch,jungle,acacia,dark_oak,crimson,warped,"
                    "mangrove,cherry,pale_oak,bamboo,poplar"
                ),
                Int(self._wood),
            )
        )

    def flammable(self) -> Bool:
        """Reports whether the wood burns (Go `Flammable`)."""
        return self != WoodType.CRIMSON and self != WoodType.WARPED

    def leaves(self) -> Optional[LeavesType]:
        """Returns the leaves type of trees of the wood (Go `Leaves`)."""
        if self._wood <= 5:
            return LeavesType(Int(self._wood))
        if self == WoodType.MANGROVE:
            return LeavesType.MANGROVE
        if self == WoodType.CHERRY:
            return LeavesType.CHERRY
        if self == WoodType.PALE_OAK:
            return LeavesType.PALE_OAK
        return None


def wood_types() -> List[WoodType]:
    """Returns every wood type (Go `WoodTypes`)."""
    var out = List[WoodType](capacity=13)
    for i in range(13):
        out.append(WoodType(i))
    return out^
