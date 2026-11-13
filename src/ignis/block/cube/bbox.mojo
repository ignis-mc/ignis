"""Axis aligned bounding boxes, ported from Dragonfly
`server/block/cube/bbox.go`.

Only the float64 box and the methods the world uses are ported so far.
"""

from ...mgl64 import Vec3


@fieldwise_init
struct BBox(Defaultable, Equatable, ImplicitlyCopyable, Writable):
    """An axis aligned bounding box (Go `cube.BBox`)."""

    var _min: Vec3
    var _max: Vec3

    def __init__(out self):
        """Creates the zero box (Go `cube.BBox{}`)."""
        self._min = Vec3()
        self._max = Vec3()

    @staticmethod
    def box(
        x0: Float64,
        y0: Float64,
        z0: Float64,
        x1: Float64,
        y1: Float64,
        z1: Float64,
    ) -> BBox:
        """Creates a box from two corners, swapping coordinates so that it is
        well-formed (Go `Box`).

        Args:
            x0: The first X coordinate.
            y0: The first Y coordinate.
            z0: The first Z coordinate.
            x1: The second X coordinate.
            y1: The second Y coordinate.
            z1: The second Z coordinate.

        Returns:
            The box.
        """
        return BBox(
            Vec3(min(x0, x1), min(y0, y1), min(z0, z1)),
            Vec3(max(x0, x1), max(y0, y1), max(z0, z1)),
        )

    def min(self) -> Vec3:
        """Returns the minimum corner (Go `Min`).

        Returns:
            The corner.
        """
        return self._min

    def max(self) -> Vec3:
        """Returns the maximum corner (Go `Max`).

        Returns:
            The corner.
        """
        return self._max

    def grow(self, x: Float64) -> BBox:
        """Grows the box by `x` in every direction (Go `Grow`).

        Args:
            x: The amount.

        Returns:
            The grown box.
        """
        return self.grow_vec3(Vec3(x, x, x))

    def grow_vec3(self, v: Vec3) -> BBox:
        """Grows the box per axis (Go `GrowVec3`).

        Args:
            v: The amount per axis.

        Returns:
            The grown box.
        """
        return BBox(self._min.sub(v), self._max.add(v))

    def translate(self, v: Vec3) -> BBox:
        """Moves the box (Go `Translate`).

        Args:
            v: The offset.

        Returns:
            The moved box.
        """
        return BBox(self._min.add(v), self._max.add(v))

    def vec3_within(self, v: Vec3) -> Bool:
        """Reports whether a point lies strictly inside the box (Go
        `Vec3Within`).

        Args:
            v: The point.

        Returns:
            True if inside.
        """
        if v.x() <= self._min.x() or v.x() >= self._max.x():
            return False
        if v.z() <= self._min.z() or v.z() >= self._max.z():
            return False
        return v.y() > self._min.y() and v.y() < self._max.y()

    def write_to(self, mut writer: Some[Writer]):
        """Writes the box as `{min max}`.

        Args:
            writer: The destination.
        """
        writer.write("{", self._min, " ", self._max, "}")
