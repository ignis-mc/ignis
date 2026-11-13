"""The part of go-gl/mathgl's `mgl64` that Ignis uses.

Dragonfly uses `mgl64.Vec3` for positions everywhere. The protocol
submodule's `Vec3` is the 32-bit `mgl32.Vec3` used on the wire; this is the
64-bit one used by the server.
"""

from std.math import sqrt


@fieldwise_init
struct Vec3(Defaultable, Equatable, ImplicitlyCopyable, Writable):
    """A three-component `Float64` vector (Go `mgl64.Vec3`)."""

    var x: Float64
    """The first component."""
    var y: Float64
    """The second component."""
    var z: Float64
    """The third component."""

    def __init__(out self):
        """Creates the zero vector."""
        self.x = 0
        self.y = 0
        self.z = 0

    def __getitem__(self, i: Int) -> Float64:
        """Gets a component by index, as Go's `v[i]`.

        Args:
            i: 0, 1 or 2.

        Returns:
            The component.
        """
        if i == 0:
            return self.x
        if i == 1:
            return self.y
        return self.z

    def __setitem__(mut self, i: Int, value: Float64):
        """Sets a component by index, as Go's `v[i] = value`.

        Args:
            i: 0, 1 or 2.
            value: The new value.
        """
        if i == 0:
            self.x = value
        elif i == 1:
            self.y = value
        else:
            self.z = value

    def __eq__(self, other: Self) -> Bool:
        """Compares component-wise.

        Args:
            other: The other vector.

        Returns:
            True if all components are equal.
        """
        return self.x == other.x and self.y == other.y and self.z == other.z

    def add(self, other: Self) -> Self:
        """Adds two vectors (Go `Add`).

        Args:
            other: The vector to add.

        Returns:
            The sum.
        """
        return Vec3(self.x + other.x, self.y + other.y, self.z + other.z)

    def sub(self, other: Self) -> Self:
        """Subtracts a vector (Go `Sub`).

        Args:
            other: The vector to subtract.

        Returns:
            The difference.
        """
        return Vec3(self.x - other.x, self.y - other.y, self.z - other.z)

    def len(self) -> Float64:
        """Gets the Euclidean length (Go `Len`).

        Returns:
            The length.
        """
        return sqrt(self.x * self.x + self.y * self.y + self.z * self.z)

    def write_to(self, mut writer: Some[Writer]):
        """Writes the vector as `[x y z]`, as Go's `%v` does.

        Args:
            writer: The destination.
        """
        writer.write("[", self.x, " ", self.y, " ", self.z, "]")
