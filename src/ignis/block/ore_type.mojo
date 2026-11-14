"""`OreType`, ported from Dragonfly `server/block/ore_type.go`."""

from ..internal.enum import enum_name


struct OreType(Equatable, ImplicitlyCopyable, Writable):
    """The rock an ore is embedded in (Go `OreType`)."""

    var _v: UInt8

    comptime STONE = OreType(0)
    """Go `StoneOre()`."""
    comptime DEEPSLATE = OreType(1)
    """Go `DeepslateOre()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `OreType{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`)."""
        return enum_name("Stone,Deepslate", Int(self._v))

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`)."""
        writer.write(enum_name("stone,deepslate", Int(self._v)))

    def prefix(self) -> StaticString:
        """Returns the prefix of ore block names (Go `Prefix`)."""
        return enum_name(",deepslate_", Int(self._v))

    def hardness(self) -> Float64:
        """Returns the hardness of ores of the type (Go `Hardness`)."""
        return 3 if self._v == 0 else 4.5


def ore_types() -> List[OreType]:
    """Returns every ore type (Go `OreTypes`)."""
    var out = List[OreType](capacity=2)
    for i in range(2):
        out.append(OreType(i))
    return out^
