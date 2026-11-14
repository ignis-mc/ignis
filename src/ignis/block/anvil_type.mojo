"""`AnvilType`, ported from Dragonfly `server/block/anvil_type.go`."""

from ..internal.enum import enum_name


struct AnvilType(Equatable, ImplicitlyCopyable, Writable):
    """How damaged an anvil is (Go `AnvilType`)."""

    var _v: UInt8

    comptime UNDAMAGED = AnvilType(0)
    """Go `UndamagedAnvil()`."""
    comptime SLIGHTLY_DAMAGED = AnvilType(1)
    """Go `SlightlyDamagedAnvil()`."""
    comptime VERY_DAMAGED = AnvilType(2)
    """Go `VeryDamagedAnvil()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `AnvilType{v}`)."""
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
            enum_name("anvil,chipped_anvil,damaged_anvil", Int(self._v))
        )


def anvil_types() -> List[AnvilType]:
    """Returns every anvil type (Go `AnvilTypes`)."""
    var out = List[AnvilType](capacity=3)
    for i in range(3):
        out.append(AnvilType(i))
    return out^
