"""Rotations, ported from Dragonfly `server/block/cube/rotation.go`."""

from std.math import copysign, floor, trunc

from ...internal.gomath import go_cos, go_sin

from ...mgl64 import Vec3, deg_to_rad
from .direction import Direction
from .orientation import Orientation


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
        """Returns the yaw (Go `r[0]`)."""
        return self._yaw

    def pitch(self) -> Float64:
        """Returns the pitch (Go `r[1]`)."""
        return self._pitch

    def add(self, r2: Self) -> Self:
        """Adds two rotations element-wise, wrapping the yaw and clamping the
        pitch into range (Go `Add`)."""
        return Self(self._yaw + r2._yaw, self._pitch + r2._pitch)._fix()

    def elem(self) -> Tuple[Float64, Float64]:
        """Returns the yaw and the pitch (Go `Elem`)."""
        return (self._yaw, self._pitch)

    def opposite(self) -> Self:
        """Returns the rotation pointing the other way (Go `Opposite`)."""
        var fixed = self._fix()
        return Self(fixed._yaw + 180, -fixed._pitch)._fix()

    def neg(self) -> Self:
        """Negates both angles (Go `Neg`)."""
        var fixed = self._fix()
        return Self(-fixed._yaw, -fixed._pitch)

    def direction(self) -> Direction:
        """Returns the horizontal direction the rotation points in (Go
        `Direction`)."""
        var yaw = self._fix()._yaw
        if yaw > 45 and yaw <= 135:
            return Direction.WEST
        if yaw > -45 and yaw <= 45:
            return Direction.SOUTH
        if yaw > -135 and yaw <= -45:
            return Direction.EAST
        if yaw <= -135 or yaw > 135:
            return Direction.NORTH
        return Direction(0)

    def orientation(self) -> Orientation:
        """Returns the orientation closest to the yaw (Go `Orientation`)."""
        comptime step = 360 / 16.0
        var yaw = self._fix()._yaw
        if yaw < -step / 2:
            yaw += 360
        var x = yaw / step
        # Go math.Round: half away from zero.
        var r = floor(x + 0.5) if x >= 0 else -floor(-x + 0.5)
        return Orientation(Int(r))

    def vec3(self) -> Vec3:
        """Returns the unit direction vector of the rotation (Go `Vec3`)."""
        var fixed = self._fix()
        var yaw_rad = deg_to_rad(fixed._yaw)
        var pitch_rad = deg_to_rad(fixed._pitch)
        var m = go_cos(pitch_rad)
        return Vec3(
            -m * go_sin(yaw_rad), -go_sin(pitch_rad), m * go_cos(yaw_rad)
        )

    def _fix(self) -> Self:
        # Go `fix`: math.Mod keeps the sign of the dividend, and Copysign
        # gives -0 a negative sign.
        var sign_yaw = copysign(180.0, self._yaw)
        var sign_pitch = copysign(90.0, self._pitch)
        return Self(
            _go_mod(self._yaw + sign_yaw, 360) - sign_yaw,
            _go_mod(self._pitch + sign_pitch, 180) - sign_pitch,
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the rotation as `[yaw pitch]`."""
        writer.write("[", self._yaw, " ", self._pitch, "]")


def _go_mod(x: Float64, y: Float64) -> Float64:
    """Go `math.Mod`: the remainder of x/y with the sign of x."""
    return x - y * trunc(x / y)
