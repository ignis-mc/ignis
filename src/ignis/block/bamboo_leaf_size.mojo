"""`BambooLeafSize`, ported from Dragonfly `server/block/bamboo_leaf_size.go`.
"""

from ..internal.enum import enum_name


struct BambooLeafSize(Equatable, ImplicitlyCopyable, Writable):
    """The size of the leaves on bamboo (Go `BambooLeafSize`)."""

    var _v: UInt8

    comptime NO_LEAVES = BambooLeafSize(0)
    """Go `BambooSizeNoLeaves()`."""
    comptime SMALL_LEAVES = BambooLeafSize(1)
    """Go `BambooSizeSmallLeaves()`."""
    comptime LARGE_LEAVES = BambooLeafSize(2)
    """Go `BambooSizeLargeLeaves()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `BambooLeafSize{v}`).

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
        return enum_name("No Leaves,Small Leaves,Large Leaves", Int(self._v))

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(
            enum_name("no_leaves,small_leaves,large_leaves", Int(self._v))
        )


def bamboo_leaf_sizes() -> List[BambooLeafSize]:
    """Returns every leaf size (Go `BambooLeafSizes`).

    Returns:
        The values.
    """
    var out = List[BambooLeafSize](capacity=3)
    for i in range(3):
        out.append(BambooLeafSize(i))
    return out^
