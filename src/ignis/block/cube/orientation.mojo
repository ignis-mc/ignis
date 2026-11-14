"""Orientations, ported from Dragonfly `server/block/cube/orientation.go`."""

from std.math import floor, trunc


struct Orientation(Equatable, ImplicitlyCopyable, Intable):
    """One of 16 rotations around the vertical axis, as signs and banners
    standing on the ground use (Go `cube.Orientation`, an `int`)."""

    var _o: Int

    def __init__(out self, o: Int):
        """Creates an orientation from its value (Go `cube.Orientation(o)`).

        Args:
            o: 0 to 15; 0 faces south and each step is 22.5 degrees.
        """
        self._o = o

    def __int__(self) -> Int:
        """Returns the value of the orientation (Go `int(o)`).

        Returns:
            The value.
        """
        return self._o

    def __eq__(self, other: Self) -> Bool:
        """Compares two orientations.

        Args:
            other: The orientation to compare with.

        Returns:
            True if both have the same value.
        """
        return self._o == other._o

    def yaw(self) -> Float64:
        """Returns the yaw of the orientation (Go `Yaw`).

        Returns:
            The yaw in degrees.
        """
        return Float64(self._o) / 16 * 360

    def opposite(self) -> Orientation:
        """Returns the orientation rotated 180 degrees (Go `Opposite`).

        Returns:
            The opposite orientation.
        """
        return orientation_from_yaw(self.yaw() + 180)

    def rotate_left(self) -> Orientation:
        """Rotates the orientation 90 degrees counter-clockwise (Go
        `RotateLeft`).

        Returns:
            The rotated orientation.
        """
        return orientation_from_yaw(self.yaw() - 90)

    def rotate_right(self) -> Orientation:
        """Rotates the orientation 90 degrees clockwise (Go `RotateRight`).

        Returns:
            The rotated orientation.
        """
        return orientation_from_yaw(self.yaw() + 90)


def orientation_from_yaw(yaw: Float64) -> Orientation:
    """Returns the orientation closest to a yaw (Go `OrientationFromYaw`).

    As in Go, the yaw is reduced with a truncating modulo (`math.Mod`) and
    rounded half away from zero (`math.Round`), so negative yaws give
    negative orientations.

    Args:
        yaw: The yaw in degrees.

    Returns:
        The orientation.
    """
    var y = yaw - trunc(yaw / 360) * 360
    var x = y / 360 * 16
    var r = floor(x + 0.5) if x >= 0 else -floor(-x + 0.5)
    return Orientation(Int(r))
