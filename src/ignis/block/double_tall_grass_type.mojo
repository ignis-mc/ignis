"""`DoubleTallGrassType`, ported from Dragonfly `server/block/double_tall_grass_type.go`.
"""

from ..internal.enum import enum_name


struct DoubleTallGrassType(Equatable, ImplicitlyCopyable, Writable):
    """A type of double tall grass (Go `DoubleTallGrassType`)."""

    var _v: UInt8

    comptime NORMAL = DoubleTallGrassType(0)
    """Go `NormalDoubleTallGrass()`."""
    comptime FERN = DoubleTallGrassType(1)
    """Go `FernDoubleTallGrass()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `DoubleTallGrassType{v}`).

        Args:
            v: 0 to 1.
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
            0 to 1.
        """
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`).

        Returns:
            The name.
        """
        return enum_name("Tall Grass,Large Fern", Int(self._v))

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(enum_name("tall_grass,large_fern", Int(self._v)))


def double_tall_grass_types() -> List[DoubleTallGrassType]:
    """Returns every double tall grass type (Go `DoubleTallGrassTypes`).

    Returns:
        The values.
    """
    var out = List[DoubleTallGrassType](capacity=2)
    for i in range(2):
        out.append(DoubleTallGrassType(i))
    return out^
