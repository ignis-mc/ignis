"""`CopperType`, ported from Dragonfly `server/block/copper_type.go`.
"""

from ..internal.enum import enum_name


struct CopperType(Equatable, ImplicitlyCopyable, Writable):
    """A type of copper block (Go `CopperType`)."""

    var _v: UInt8

    comptime NORMAL = CopperType(0)
    """Go `NormalCopper()`."""
    comptime CUT = CopperType(1)
    """Go `CutCopper()`."""
    comptime CHISELED = CopperType(2)
    """Go `ChiseledCopper()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `CopperType{v}`).

        Args:
            v: 0 to 2.
        """
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values.

        Args:
            other: The value to compare with.

        Returns:
            True if both are the same.
        """
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`).

        Returns:
            0 to 2.
        """
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`).

        Returns:
            The name.
        """
        return enum_name("Copper,Cut Copper,Chiseled Copper", Int(self._v))

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(enum_name("default,cut,chiseled", Int(self._v)))


def copper_types() -> List[CopperType]:
    """Returns every copper type (Go `CopperTypes`).

    Returns:
        The values.
    """
    var out = List[CopperType](capacity=3)
    for i in range(3):
        out.append(CopperType(i))
    return out^
