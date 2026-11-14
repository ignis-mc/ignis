"""Attachments of signs, banners and skulls, ported from Dragonfly
`server/block/attachment.go`.

Dragonfly's `RotateRight` rotates left, like `RotateLeft`; here it rotates
right. `Rotation` waits for `cube.Rotation`: TODO(world-runtime).
"""

from .cube.direction import Direction
from .cube.orientation import Orientation


@fieldwise_init
struct Attachment(Equatable, ImplicitlyCopyable):
    """How a block is attached: to the side of a block, facing a direction,
    or standing on top of one with one of 16 orientations (Go
    `Attachment`)."""

    var _hanging: Bool
    var _facing: Direction
    var _o: Orientation

    def __init__(out self):
        """Creates a standing attachment with orientation 0 (Go
        `Attachment{}`)."""
        self = Attachment(False, Direction.NORTH, Orientation(0))

    def __eq__(self, other: Self) -> Bool:
        """Compares two attachments field by field (Go `==`)."""
        return (
            self._hanging == other._hanging
            and self._facing == other._facing
            and self._o == other._o
        )

    def hanging(self) -> Bool:
        """Reports whether the block is attached to the side of a block."""
        return self._hanging

    def facing(self) -> Direction:
        """Returns the direction a wall attachment faces."""
        return self._facing

    def orientation(self) -> Orientation:
        """Returns the orientation of a standing attachment."""
        return self._o

    def uint8(self) -> UInt8:
        """Packs the attachment into a byte (Go `Uint8`)."""
        if not self._hanging:
            return 1 | (UInt8(Int(self._o)) << 1)
        return UInt8(Int(self._facing)) << 1

    def face_uint8(self) -> UInt8:
        """Packs the attachment into a byte, ignoring the orientation (Go
        `FaceUint8`)."""
        if not self._hanging:
            return 1
        return UInt8(Int(self._facing)) << 1

    def rotate_left(self) -> Attachment:
        """Rotates the attachment 90 degrees counter-clockwise (Go
        `RotateLeft`)."""
        return Attachment(
            self._hanging, self._facing.rotate_left(), self._o.rotate_left()
        )

    def rotate_right(self) -> Attachment:
        """Rotates the attachment 90 degrees clockwise (Go `RotateRight`,
        which rotates left; see the module docstring)."""
        return Attachment(
            self._hanging, self._facing.rotate_right(), self._o.rotate_right()
        )


def wall_attachment(facing: Direction) -> Attachment:
    """Returns an attachment to the side of a block (Go `WallAttachment`)."""
    return Attachment(True, facing, Orientation(0))


def standing_attachment(o: Orientation) -> Attachment:
    """Returns an attachment on top of a block (Go `StandingAttachment`)."""
    return Attachment(False, Direction.NORTH, o)


def attachment_from_uint8(v: Int) -> Attachment:
    """Unpacks the value `uint8` returns."""
    if v & 1 != 0:
        return standing_attachment(Orientation(v >> 1))
    return wall_attachment(Direction(v >> 1))
