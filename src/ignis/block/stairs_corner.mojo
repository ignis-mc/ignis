"""`StairsCorner`, ported from Dragonfly `server/block/stairs_corner.go`.
"""

from ..internal.enum import enum_name


struct StairsCorner(Equatable, ImplicitlyCopyable, Writable):
    """The corner stairs form with the stairs around them (Go `StairsCorner`).
    """

    var _v: UInt8

    comptime NONE = StairsCorner(0)
    """Go `NoStairsCorner()`."""
    comptime INNER_LEFT = StairsCorner(1)
    """Go `InnerLeftStairsCorner()`."""
    comptime INNER_RIGHT = StairsCorner(2)
    """Go `InnerRightStairsCorner()`."""
    comptime OUTER_LEFT = StairsCorner(3)
    """Go `OuterLeftStairsCorner()`."""
    comptime OUTER_RIGHT = StairsCorner(4)
    """Go `OuterRightStairsCorner()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `StairsCorner{v}`).

        Args:
            v: 0 to 4.
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
            0 to 4.
        """
        return self._v

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(
            enum_name(
                "none,inner_left,inner_right,outer_left,outer_right",
                Int(self._v),
            )
        )

    def inner(self) -> Bool:
        """Reports whether the corner is an inner corner (Go `Inner`).

        Returns:
            True for the inner corners.
        """
        return self._v == 1 or self._v == 2

    def left(self) -> Bool:
        """Reports whether the corner is a left corner (Go `Left`).

        Returns:
            True for the left corners.
        """
        return self._v == 1 or self._v == 3


def stairs_corners() -> List[StairsCorner]:
    """Returns every corner (Go `StairsCorners`).

    Returns:
        The values.
    """
    var out = List[StairsCorner](capacity=5)
    for i in range(5):
        out.append(StairsCorner(i))
    return out^
