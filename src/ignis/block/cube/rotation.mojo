"""Rotations, ported from Dragonfly `server/block/cube/rotation.go`.

Only the accessors and `Add` are ported so far.
"""

from std.math import trunc


@fieldwise_init
struct Rotation(Defaultable, Equatable, ImplicitlyCopyable, Writable):
    """The rotation of an object in degrees: a yaw in (-180, 180] and a pitch
    in [-90, 90], positive looking down (Go `cube.Rotation`, `[2]float64`).
    """

    var _yaw: Float64
    var _pitch: Float64

    def __init__(out self):
        """Creates the zero rotation."""
        self._yaw = 0
        self._pitch = 0

    def yaw(self) -> Float64:
        """Returns the yaw (Go `r[0]`).

        Returns:
            The yaw in degrees.
        """
        return self._yaw

    def pitch(self) -> Float64:
        """Returns the pitch (Go `r[1]`).

        Returns:
            The pitch in degrees.
        """
        return self._pitch

    def add(self, r2: Self) -> Self:
        """Adds two rotations element-wise, wrapping the yaw and clamping the
        pitch into range (Go `Add`).

        Args:
            r2: The rotation to add.

        Returns:
            The sum.
        """
        return Self(self._yaw + r2._yaw, self._pitch + r2._pitch)._fix()

    def _fix(self) -> Self:
        # Go `fix`: math.Mod keeps the sign of the dividend.
        var sign_yaw = 180.0 if self._yaw >= 0 else -180.0
        var sign_pitch = 90.0 if self._pitch >= 0 else -90.0
        return Self(
            _go_mod(self._yaw + sign_yaw, 360) - sign_yaw,
            _go_mod(self._pitch + sign_pitch, 180) - sign_pitch,
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the rotation as `[yaw pitch]`.

        Args:
            writer: The destination.
        """
        writer.write("[", self._yaw, " ", self._pitch, "]")


def _go_mod(x: Float64, y: Float64) -> Float64:
    """Go `math.Mod`: the remainder of x/y with the sign of x."""
    return x - y * trunc(x / y)
