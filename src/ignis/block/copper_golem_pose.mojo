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
        """Creates the value with index `v` (Go `CopperGolemPose{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`)."""
        return enum_name("Standing,Sitting,Running,Star", Int(self._v))


def copper_golem_poses() -> List[CopperGolemPose]:
    """Returns every pose (Go `CopperGolemPoses`)."""
    var out = List[CopperGolemPose](capacity=4)
    for i in range(4):
        out.append(CopperGolemPose(i))
    return out^
