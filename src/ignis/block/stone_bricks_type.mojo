"""`StoneBricksType`, ported from Dragonfly `server/block/stone_bricks_type.go`.
"""

from ..internal.enum import enum_name


struct StoneBricksType(Equatable, ImplicitlyCopyable, Writable):
    """A type of stone bricks (Go `StoneBricksType`)."""

    var _v: UInt8

    comptime NORMAL = StoneBricksType(0)
    """Go `NormalStoneBricks()`."""
    comptime MOSSY = StoneBricksType(1)
    """Go `MossyStoneBricks()`."""
    comptime CRACKED = StoneBricksType(2)
    """Go `CrackedStoneBricks()`."""
    comptime CHISELED = StoneBricksType(3)
    """Go `ChiseledStoneBricks()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `StoneBricksType{v}`).

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
                "Stone Bricks,Mossy Stone Bricks,Cracked Stone Bricks,"
                "Chiseled Stone Bricks"
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
                    "stone_bricks,mossy_stone_bricks,cracked_stone_bricks,"
                    "chiseled_stone_bricks"
                ),
                Int(self._v),
            )
        )


def stone_bricks_types() -> List[StoneBricksType]:
    """Returns every stone bricks type (Go `StoneBricksTypes`).

    Returns:
        The values.
    """
    var out = List[StoneBricksType](capacity=4)
    for i in range(4):
        out.append(StoneBricksType(i))
    return out^
