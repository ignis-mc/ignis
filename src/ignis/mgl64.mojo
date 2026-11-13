"""The parts of `github.com/go-gl/mathgl/mgl64` that Dragonfly uses: `Vec3`.

Go's `mgl64.Vec3` is a `[3]float64`; here it is a struct with `x`, `y` and
`z` methods mirroring `v[0]`, `v[1]` and `v[2]`.
"""

from std.math import sqrt


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
        """Returns the first element (Go `v[0]`).

        Returns:
            The X value.
        """
        return self._x

    def y(self) -> Float64:
        """Returns the second element (Go `v[1]`).

        Returns:
            The Y value.
        """
        return self._y

    def z(self) -> Float64:
        """Returns the third element (Go `v[2]`).

        Returns:
            The Z value.
        """
        return self._z

    def add(self, o: Self) -> Self:
        """Adds two vectors (Go `Add`).

        Args:
            o: The vector to add.

        Returns:
            The sum.
        """
        return Self(self._x + o._x, self._y + o._y, self._z + o._z)

    def sub(self, o: Self) -> Self:
        """Subtracts a vector (Go `Sub`).

        Args:
            o: The vector to subtract.

        Returns:
            The difference.
        """
        return Self(self._x - o._x, self._y - o._y, self._z - o._z)

    def mul(self, c: Float64) -> Self:
        """Scales the vector (Go `Mul`).

        Args:
            c: The factor.

        Returns:
            The scaled vector.
        """
        return Self(self._x * c, self._y * c, self._z * c)

    def len(self) -> Float64:
        """Returns the length of the vector (Go `Len`).

        Returns:
            The Euclidean length.
        """
        return sqrt(self._x * self._x + self._y * self._y + self._z * self._z)

    def write_to(self, mut writer: Some[Writer]):
        """Writes the vector as `[x y z]`, as Go prints it.

        Args:
            writer: The destination.
        """
        writer.write("[", self._x, " ", self._y, " ", self._z, "]")
