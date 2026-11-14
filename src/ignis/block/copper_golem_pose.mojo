"""`CopperGolemPose`, ported from Dragonfly `server/block/copper_golem_pose.go`.
"""

from ..internal.enum import enum_name


struct CopperGolemPose(Equatable, ImplicitlyCopyable):
    """The pose of a copper golem statue (Go `CopperGolemPose`)."""

    var _v: UInt8

    comptime STANDING = CopperGolemPose(0)
    """Go `StandingPose()`."""
    comptime SITTING = CopperGolemPose(1)
    """Go `SittingPose()`."""
    comptime RUNNING = CopperGolemPose(2)
    """Go `RunningPose()`."""
    comptime STAR = CopperGolemPose(3)
    """Go `StarPose()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `CopperGolemPose{v}`).

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
        return enum_name("Standing,Sitting,Running,Star", Int(self._v))


def copper_golem_poses() -> List[CopperGolemPose]:
    """Returns every pose (Go `CopperGolemPoses`).

    Returns:
        The values.
    """
    var out = List[CopperGolemPose](capacity=4)
    for i in range(4):
        out.append(CopperGolemPose(i))
    return out^
