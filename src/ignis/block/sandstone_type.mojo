"""`SandstoneType`, ported from Dragonfly `server/block/sandstone_type.go`.
"""

from ..internal.enum import enum_name


struct SandstoneType(Equatable, ImplicitlyCopyable, Writable):
    """A type of sandstone (Go `SandstoneType`)."""

    var _v: UInt8

    comptime NORMAL = SandstoneType(0)
    """Go `NormalSandstone()`."""
    comptime CUT = SandstoneType(1)
    """Go `CutSandstone()`."""
    comptime CHISELED = SandstoneType(2)
    """Go `ChiseledSandstone()`."""
    comptime SMOOTH = SandstoneType(3)
    """Go `SmoothSandstone()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `SandstoneType{v}`).

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
            "Sandstone,Cut Sandstone,Chiseled Sandstone,Smooth Sandstone",
            Int(self._v),
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(enum_name("default,cut,chiseled,smooth", Int(self._v)))


def sandstone_types() -> List[SandstoneType]:
    """Returns every sandstone type (Go `SandstoneTypes`).

    Returns:
        The values.
    """
    var out = List[SandstoneType](capacity=4)
    for i in range(4):
        out.append(SandstoneType(i))
    return out^
