"""`PrismarineType`, ported from Dragonfly `server/block/prismarine_type.go`."""

from ..internal.enum import enum_name


struct PrismarineType(Equatable, ImplicitlyCopyable, Writable):
    """A type of prismarine (Go `PrismarineType`)."""

    var _v: UInt8

    comptime NORMAL = PrismarineType(0)
    """Go `NormalPrismarine()`."""
    comptime DARK = PrismarineType(1)
    """Go `DarkPrismarine()`."""
    comptime BRICK = PrismarineType(2)
    """Go `BrickPrismarine()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `PrismarineType{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`)."""
        writer.write(
            enum_name(
                "prismarine,dark_prismarine,prismarine_bricks", Int(self._v)
            )
        )


def prismarine_types() -> List[PrismarineType]:
    """Returns every prismarine type (Go `PrismarineTypes`)."""
    var out = List[PrismarineType](capacity=3)
    for i in range(3):
        out.append(PrismarineType(i))
    return out^
