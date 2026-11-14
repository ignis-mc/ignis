"""`DoubleFlowerType`, ported from Dragonfly `server/block/double_flower_type.go`.
"""

from ..internal.enum import enum_name


struct DoubleFlowerType(Equatable, ImplicitlyCopyable, Writable):
    """A type of two block high flower (Go `DoubleFlowerType`)."""

    var _v: UInt8

    comptime SUNFLOWER = DoubleFlowerType(0)
    """Go `Sunflower()`."""
    comptime LILAC = DoubleFlowerType(1)
    """Go `Lilac()`."""
    comptime ROSE_BUSH = DoubleFlowerType(4)
    """Go `RoseBush()`."""
    comptime PEONY = DoubleFlowerType(5)
    """Go `Peony()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `DoubleFlowerType{v}`).

        Args:
            v: 0 to 5.
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
            0 to 5.
        """
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`).

        Returns:
            The name.
        """
        return enum_name("Sunflower,Lilac,,,Rose Bush,Peony", Int(self._v))

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(
            enum_name("sunflower,lilac,,,rose_bush,peony", Int(self._v))
        )


def double_flower_types() -> List[DoubleFlowerType]:
    """Returns every double flower type (Go `DoubleFlowerTypes`).

    Returns:
        The values.
    """
    return [
        DoubleFlowerType.SUNFLOWER,
        DoubleFlowerType.LILAC,
        DoubleFlowerType.ROSE_BUSH,
        DoubleFlowerType.PEONY,
    ]
