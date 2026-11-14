"""`FroglightType`, ported from Dragonfly `server/block/froglight_type.go`.
"""

from ..internal.enum import enum_name


struct FroglightType(Equatable, ImplicitlyCopyable, Writable):
    """A type of froglight (Go `FroglightType`)."""

    var _v: UInt8

    comptime PEARLESCENT = FroglightType(0)
    """Go `Pearlescent()`."""
    comptime VERDANT = FroglightType(1)
    """Go `Verdant()`."""
    comptime OCHRE = FroglightType(2)
    """Go `Ochre()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `FroglightType{v}`).

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
        return enum_name("Pearlescent,Verdant,Ochre", Int(self._v))

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(enum_name("pearlescent,verdant,ochre", Int(self._v)))


def froglight_types() -> List[FroglightType]:
    """Returns every froglight type (Go `FroglightTypes`).

    Returns:
        The values.
    """
    var out = List[FroglightType](capacity=3)
    for i in range(3):
        out.append(FroglightType(i))
    return out^
