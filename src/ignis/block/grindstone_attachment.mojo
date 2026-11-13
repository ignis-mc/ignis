"""`GrindstoneAttachment`, ported from Dragonfly `server/block/grindstone_attachment.go`.
"""

from ..internal.enum import enum_name


struct GrindstoneAttachment(Equatable, ImplicitlyCopyable, Writable):
    """How a grindstone is attached (Go `GrindstoneAttachment`)."""

    var _v: UInt8

    comptime STANDING = GrindstoneAttachment(0)
    """Go `StandingGrindstoneAttachment()`."""
    comptime HANGING = GrindstoneAttachment(1)
    """Go `HangingGrindstoneAttachment()`."""
    comptime WALL = GrindstoneAttachment(2)
    """Go `WallGrindstoneAttachment()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `GrindstoneAttachment{v}`).

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
        writer.write(enum_name("standing,hanging,side", Int(self._v)))


def grindstone_attachments() -> List[GrindstoneAttachment]:
    """Returns every attachment (Go `GrindstoneAttachments`).

    Returns:
        The values.
    """
    var out = List[GrindstoneAttachment](capacity=3)
    for i in range(3):
        out.append(GrindstoneAttachment(i))
    return out^
