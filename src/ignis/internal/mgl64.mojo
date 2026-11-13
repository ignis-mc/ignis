"""The `mgl64.Vec3` subset Dragonfly uses for positions and velocities
(github.com/go-gl/mathgl/mgl64)."""

from std.math import sqrt

from minecraft.protocol.math import Vec3 as ProtocolVec3


comptime _EPSILON = 1e-10
"""mgl64's `Epsilon`, used by `float_equal`."""
comptime _MIN_NORMAL = 2.2250738585072014e-308
"""mgl64's `MinNormal`: the smallest normal `Float64`."""


@fieldwise_init
struct Vec3(Equatable, ImplicitlyCopyable, Writable):
    """A three-component vector of `Float64` (Go `mgl64.Vec3`)."""

    var x: Float64
    """The X component."""
    var y: Float64
    """The Y component."""
    var z: Float64
    """The Z component."""

    def __init__(out self):
        """Creates the zero vector."""
        self.x = 0
        self.y = 0
        self.z = 0

    @staticmethod
    def from_protocol(v: ProtocolVec3) -> Vec3:
        """Widens a network vector (Go `vec32To64`).

        Args:
            v: The `Float32` vector.

        Returns:
            The same vector in `Float64`.
        """
        return Vec3(Float64(v.x), Float64(v.y), Float64(v.z))

    def to_protocol(self) -> ProtocolVec3:
        """Narrows to a network vector (Go `vec64To32`).

        Returns:
            The vector in `Float32`.
        """
        return ProtocolVec3(Float32(self.x), Float32(self.y), Float32(self.z))

    def __add__(self, o: Self) -> Self:
        """Adds two vectors (Go `Add`).

        Args:
            o: The other vector.

        Returns:
            The sum.
        """
        return Self(self.x + o.x, self.y + o.y, self.z + o.z)

    def __sub__(self, o: Self) -> Self:
        """Subtracts a vector (Go `Sub`).

        Args:
            o: The vector to subtract.

        Returns:
            The difference.
        """
        return Self(self.x - o.x, self.y - o.y, self.z - o.z)

    def len(self) -> Float64:
        """Returns the length (Go `Len`).

        Returns:
            The Euclidean length.
        """
        return sqrt(self.x * self.x + self.y * self.y + self.z * self.z)

    def approx_equal(self, o: Self) -> Bool:
        """Compares component-wise with `float_equal` (Go `ApproxEqual`).

        Args:
            o: The other vector.

        Returns:
            True if every component is approximately equal.
        """
        return (
            float_equal(self.x, o.x)
            and float_equal(self.y, o.y)
            and float_equal(self.z, o.z)
        )

    def __eq__(self, o: Self) -> Bool:
        """Compares exactly.

        Args:
            o: The other vector.

        Returns:
            True if every component is equal.
        """
        return self.x == o.x and self.y == o.y and self.z == o.z

    def write_to(self, mut writer: Some[Writer]):
        """Writes the vector as `[x y z]`, like Go's `%v`.

        Args:
            writer: The writer.
        """
        writer.write("[", self.x, " ", self.y, " ", self.z, "]")


def float_equal(a: Float64, b: Float64) -> Bool:
    """Compares floats with mgl64's relative tolerance (Go `FloatEqual`).

    Args:
        a: The first value.
        b: The second value.

    Returns:
        True if the values are equal within `1e-10`, absolute near zero and
        relative otherwise.
    """
    if a == b:
        return True
    var diff = abs(a - b)
    if a * b == 0 or diff < _MIN_NORMAL:
        return diff < _EPSILON * _EPSILON
    return diff / (abs(a) + abs(b)) < _EPSILON
