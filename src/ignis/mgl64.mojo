"""The parts of `github.com/go-gl/mathgl/mgl64` (v1.2.0) that Dragonfly
uses: `Vec3`, `FloatEqual` and `DegToRad`.

Go's `mgl64.Vec3` is a `[3]float64`; here it is a struct with `x`, `y` and
`z` methods mirroring `v[0]`, `v[1]` and `v[2]`.
"""

from std.math import pi, sqrt


@fieldwise_init
struct Vec3(Defaultable, Equatable, ImplicitlyCopyable, Writable):
    """A vector of three float64 values (Go `mgl64.Vec3`)."""

    var _x: Float64
    var _y: Float64
    var _z: Float64

    def __init__(out self):
        """Creates the zero vector."""
        self._x = 0
        self._y = 0
        self._z = 0

    def x(self) -> Float64:
        """Returns the first element (Go `v[0]`)."""
        return self._x

    def y(self) -> Float64:
        """Returns the second element (Go `v[1]`)."""
        return self._y

    def z(self) -> Float64:
        """Returns the third element (Go `v[2]`)."""
        return self._z

    def __getitem__(self, i: Int) -> Float64:
        """Returns an element by index (Go `v[i]`)."""
        if i == 0:
            return self._x
        if i == 1:
            return self._y
        return self._z

    def with_elem(self, i: Int, v: Float64) -> Self:
        """Returns the vector with one element replaced (Go `v[i] = x` on a
        copy)."""
        if i == 0:
            return Self(v, self._y, self._z)
        if i == 1:
            return Self(self._x, v, self._z)
        return Self(self._x, self._y, v)

    def add(self, o: Self) -> Self:
        """Adds two vectors (Go `Add`)."""
        return Self(self._x + o._x, self._y + o._y, self._z + o._z)

    def sub(self, o: Self) -> Self:
        """Subtracts a vector (Go `Sub`)."""
        return Self(self._x - o._x, self._y - o._y, self._z - o._z)

    def mul(self, c: Float64) -> Self:
        """Scales the vector (Go `Mul`)."""
        return Self(self._x * c, self._y * c, self._z * c)

    def len(self) -> Float64:
        """Returns the length of the vector (Go `Len`)."""
        return sqrt(self._x * self._x + self._y * self._y + self._z * self._z)

    def len_sqr(self) -> Float64:
        """Returns the squared length of the vector (Go `LenSqr`)."""
        return self._x * self._x + self._y * self._y + self._z * self._z

    def normalize(self) -> Self:
        """Scales the vector to length 1 (Go `Normalize`)."""
        var l = 1.0 / self.len()
        return Self(self._x * l, self._y * l, self._z * l)

    def dot(self, o: Self) -> Float64:
        """Returns the dot product (Go `Dot`)."""
        return self._x * o._x + self._y * o._y + self._z * o._z

    def write_to(self, mut writer: Some[Writer]):
        """Writes the vector as `[x y z]`, as Go prints it."""
        writer.write("[", self._x, " ", self._y, " ", self._z, "]")


comptime EPSILON: Float64 = 1e-10
"""How precisely `float_equal` compares (Go `mgl64.Epsilon`)."""
comptime MIN_NORMAL: Float64 = 1.1754943508222875e-38
"""The smallest normal float32 (Go `mgl64.MinNormal`)."""


def float_equal_threshold(a: Float64, b: Float64, epsilon: Float64) -> Bool:
    """Compares two floats relative to their size (Go
    `FloatEqualThreshold`)."""
    if a == b:
        return True
    var diff = abs(a - b)
    if a * b == 0 or diff < MIN_NORMAL:
        return diff < epsilon * epsilon
    return diff / (abs(a) + abs(b)) < epsilon


def float_equal(a: Float64, b: Float64) -> Bool:
    """Compares two floats with `EPSILON` (Go `FloatEqual`)."""
    return float_equal_threshold(a, b, EPSILON)


def deg_to_rad(angle: Float64) -> Float64:
    """Converts degrees to radians (Go `DegToRad`)."""
    return angle * pi / 180


def approx_equal(a: Vec3, b: Vec3) -> Bool:
    """Compares vectors element-wise with `float_equal` (Go
    `Vec3.ApproxEqual`)."""
    return (
        float_equal(a.x(), b.x())
        and float_equal(a.y(), b.y())
        and float_equal(a.z(), b.z())
    )
