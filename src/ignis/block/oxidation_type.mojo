"""`OxidationType`, ported from Dragonfly `server/block/oxidation_type.go`.
"""

from ..internal.enum import enum_name


struct OxidationType(Equatable, ImplicitlyCopyable, Writable):
    """The oxidation level of a copper block (Go `OxidationType`)."""

    var _v: UInt8

    comptime UNOXIDISED = OxidationType(0)
    """Go `UnoxidisedOxidation()`."""
    comptime EXPOSED = OxidationType(1)
    """Go `ExposedOxidation()`."""
    comptime WEATHERED = OxidationType(2)
    """Go `WeatheredOxidation()`."""
    comptime OXIDISED = OxidationType(3)
    """Go `OxidisedOxidation()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `OxidationType{v}`).

        Args:
            v: 0 to 3.
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
            0 to 3.
        """
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`).

        Returns:
            The name.
        """
        return enum_name(",Exposed,Weathered,Oxidized", Int(self._v))

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(enum_name(",exposed,weathered,oxidized", Int(self._v)))

    def decrease(self) -> Optional[OxidationType]:
        """Returns the next lower oxidation level (Go `Decrease`).

        Returns:
            The level, or None if the copper is unoxidised.
        """
        if self._v > 0:
            return OxidationType(Int(self._v) - 1)
        return None

    def increase(self) -> Optional[OxidationType]:
        """Returns the next higher oxidation level (Go `Increase`).

        Returns:
            The level, or None if the copper is fully oxidised.
        """
        if self._v < 3:
            return OxidationType(Int(self._v) + 1)
        return None


def oxidation_types() -> List[OxidationType]:
    """Returns every oxidation level (Go `OxidationTypes`).

    Returns:
        The values.
    """
    var out = List[OxidationType](capacity=4)
    for i in range(4):
        out.append(OxidationType(i))
    return out^
