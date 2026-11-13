"""`WallConnectionType`, ported from Dragonfly `server/block/wall_connection_type.go`.
"""

from ..internal.enum import enum_name


struct WallConnectionType(Equatable, ImplicitlyCopyable, Writable):
    """The connection of a wall on one side (Go `WallConnectionType`)."""

    var _v: UInt8

    comptime NONE = WallConnectionType(0)
    """Go `NoWallConnection()`."""
    comptime SHORT = WallConnectionType(1)
    """Go `ShortWallConnection()`."""
    comptime TALL = WallConnectionType(2)
    """Go `TallWallConnection()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `WallConnectionType{v}`).

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

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(enum_name("none,short,tall", Int(self._v)))

    def height(self) -> Float64:
        """Returns the height of the connection (Go `Height`).

        Returns:
            0, 0.75 or 1.
        """
        if self._v == 0:
            return 0
        if self._v == 1:
            return 0.75
        return 1


def wall_connection_types() -> List[WallConnectionType]:
    """Returns every connection type (Go `WallConnectionTypes`).

    Returns:
        The values.
    """
    var out = List[WallConnectionType](capacity=3)
    for i in range(3):
        out.append(WallConnectionType(i))
    return out^
