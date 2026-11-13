"""`BlackstoneType`, ported from Dragonfly `server/block/blackstone_type.go`.
"""

from ..internal.enum import enum_name


struct BlackstoneType(Equatable, ImplicitlyCopyable, Writable):
    """A type of blackstone (Go `BlackstoneType`)."""

    var _v: UInt8

    comptime NORMAL = BlackstoneType(0)
    """Go `NormalBlackstone()`."""
    comptime GILDED = BlackstoneType(1)
    """Go `GildedBlackstone()`."""
    comptime POLISHED = BlackstoneType(2)
    """Go `PolishedBlackstone()`."""
    comptime CHISELED_POLISHED = BlackstoneType(3)
    """Go `ChiseledPolishedBlackstone()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `BlackstoneType{v}`).

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
        return enum_name(
            (
                "Blackstone,Gilded Blackstone,Polished Blackstone,"
                "Chiseled Polished Blackstone"
            ),
            Int(self._v),
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(
            enum_name(
                (
                    "blackstone,gilded_blackstone,polished_blackstone,"
                    "chiseled_polished_blackstone"
                ),
                Int(self._v),
            )
        )


def blackstone_types() -> List[BlackstoneType]:
    """Returns every blackstone type (Go `BlackstoneTypes`).

    Returns:
        The values.
    """
    var out = List[BlackstoneType](capacity=4)
    for i in range(4):
        out.append(BlackstoneType(i))
    return out^
