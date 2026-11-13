"""Rotations, ported from Dragonfly `server/block/cube/rotation.go`."""


@fieldwise_init
struct Rotation(Equatable, ImplicitlyCopyable, Writable):
    """A yaw and pitch in degrees (Go `cube.Rotation`, `[2]float64`)."""

    var _yaw: Float64
    var _pitch: Float64

    def __init__(out self):
        """Creates the zero rotation."""
        self._yaw = 0
        self._pitch = 0

    def yaw(self) -> Float64:
        """Returns the yaw (Go `Yaw`).

        Returns:
            The yaw in degrees.
        """
        return self._yaw

    def pitch(self) -> Float64:
        """Returns the pitch (Go `Pitch`).

        Returns:
            The pitch in degrees.
        """
        return self._pitch

    def add(self, r: Self) -> Self:
        """Adds two rotations and wraps the result into range (Go `Add`).

        Args:
            r: The rotation to add.

        Returns:
            The sum, yaw in [-180, 180) and pitch in [-90, 90) as Go's `fix`
            leaves them.
        """
        return Self(self._yaw + r._yaw, self._pitch + r._pitch).fix()

    def fix(self) -> Self:
        """Wraps yaw and pitch into range (Go `fix`).

        Returns:
            The rotation with `math.Mod` applied as Go does.
        """
        var sign_yaw = _copysign(180, self._yaw)
        var sign_pitch = _copysign(90, self._pitch)
        return Self(
            _fmod(self._yaw + sign_yaw, 360) - sign_yaw,
            _fmod(self._pitch + sign_pitch, 180) - sign_pitch,
        )

    def __eq__(self, o: Self) -> Bool:
        """Compares exactly.

        Args:
            o: The other rotation.

        Returns:
            True if yaw and pitch are equal.
        """
        return self._yaw == o._yaw and self._pitch == o._pitch

    def write_to(self, mut writer: Some[Writer]):
        """Writes `[yaw pitch]`, like Go's `%v`.

        Args:
            writer: The writer.
        """
        writer.write("[", self._yaw, " ", self._pitch, "]")


def _copysign(magnitude: Float64, sign: Float64) -> Float64:
    if sign < 0 or (sign == 0 and 1 / sign < 0):
        return -magnitude
    return magnitude


def _fmod(a: Float64, b: Float64) -> Float64:
    """Go `math.Mod`: the remainder with the sign of `a`."""
    return a - b * Float64(Int(a / b))
