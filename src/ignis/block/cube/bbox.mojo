"""Axis aligned bounding boxes, ported from Dragonfly
`server/block/cube/bbox.go`.

Go's generic `boundingBox[T, V]` is used as `BBox` (float64) by the world
and as `BBox32` (float32) only by the session's movement code; `BBox32`
comes with sessions.
"""

from ...mgl64 import Vec3
from .axis import Axis
from .face import Face


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
        well-formed (Go `Box`)."""
        return BBox(
            Vec3(min(x0, x1), min(y0, y1), min(z0, z1)),
            Vec3(max(x0, x1), max(y0, y1), max(z0, z1)),
        )

    def min(self) -> Vec3:
        """Returns the minimum corner (Go `Min`)."""
        return self._min

    def max(self) -> Vec3:
        """Returns the maximum corner (Go `Max`)."""
        return self._max

    def grow(self, x: Float64) -> BBox:
        """Grows the box by `x` in every direction (Go `Grow`)."""
        return self.grow_vec3(Vec3(x, x, x))

    def grow_vec3(self, v: Vec3) -> BBox:
        """Grows the box per axis (Go `GrowVec3`)."""
        return BBox(self._min.sub(v), self._max.add(v))

    def translate(self, v: Vec3) -> BBox:
        """Moves the box (Go `Translate`)."""
        return BBox(self._min.add(v), self._max.add(v))

    def vec3_within(self, v: Vec3) -> Bool:
        """Reports whether a point lies strictly inside the box (Go
        `Vec3Within`)."""
        if v.x() <= self._min.x() or v.x() >= self._max.x():
            return False
        if v.z() <= self._min.z() or v.z() >= self._max.z():
            return False
        return v.y() > self._min.y() and v.y() < self._max.y()

    def width(self) -> Float64:
        """Returns the size on the X axis (Go `Width`)."""
        return self._max.x() - self._min.x()

    def length(self) -> Float64:
        """Returns the size on the Z axis (Go `Length`)."""
        return self._max.z() - self._min.z()

    def height(self) -> Float64:
        """Returns the size on the Y axis (Go `Height`)."""
        return self._max.y() - self._min.y()

    def extend(self, v: Vec3) -> BBox:
        """Extends the box by a vector: negative elements move the minimum,
        positive ones the maximum (Go `Extend`)."""
        var lo = self._min
        var hi = self._max
        for i in range(3):
            if v[i] < 0:
                lo = lo.with_elem(i, lo[i] + v[i])
            elif v[i] > 0:
                hi = hi.with_elem(i, hi[i] + v[i])
        return BBox(lo, hi)

    def extend_towards(self, f: Face, x: Float64) -> BBox:
        """Extends the box by `x` on one face (Go `ExtendTowards`)."""
        var lo = self._min
        var hi = self._max
        if f == Face.DOWN:
            lo = lo.with_elem(1, lo.y() - x)
        elif f == Face.UP:
            hi = hi.with_elem(1, hi.y() + x)
        elif f == Face.NORTH:
            lo = lo.with_elem(2, lo.z() - x)
        elif f == Face.SOUTH:
            hi = hi.with_elem(2, hi.z() + x)
        elif f == Face.WEST:
            lo = lo.with_elem(0, lo.x() - x)
        elif f == Face.EAST:
            hi = hi.with_elem(0, hi.x() + x)
        return BBox(lo, hi)

    def stretch(self, a: Axis, x: Float64) -> BBox:
        """Extends the box by `x` on both sides of an axis (Go `Stretch`)."""
        var i = 0
        if a == Axis.Y:
            i = 1
        elif a == Axis.Z:
            i = 2
        elif a != Axis.X:
            return self
        return BBox(
            self._min.with_elem(i, self._min[i] - x),
            self._max.with_elem(i, self._max[i] + x),
        )

    def translate_towards(self, f: Face, x: Float64) -> BBox:
        """Moves the box by `x` towards a face (Go `TranslateTowards`)."""
        if f == Face.DOWN:
            return self.translate(Vec3(0, -x, 0))
        if f == Face.UP:
            return self.translate(Vec3(0, x, 0))
        if f == Face.NORTH:
            return self.translate(Vec3(0, 0, -x))
        if f == Face.SOUTH:
            return self.translate(Vec3(0, 0, x))
        if f == Face.WEST:
            return self.translate(Vec3(-x, 0, 0))
        if f == Face.EAST:
            return self.translate(Vec3(x, 0, 0))
        return self

    def intersects_with(self, other: BBox) -> Bool:
        """Reports whether two boxes overlap by more than 1e-5 on every axis
        (Go `IntersectsWith`)."""
        return self._intersects_with(other, 1e-5)

    def _intersects_with(self, other: BBox, epsilon: Float64) -> Bool:
        if (
            other._max.x() - self._min.x() > epsilon
            and self._max.x() - other._min.x() > epsilon
        ):
            if (
                other._max.y() - self._min.y() > epsilon
                and self._max.y() - other._min.y() > epsilon
            ):
                return (
                    other._max.z() - self._min.z() > epsilon
                    and self._max.z() - other._min.z() > epsilon
                )
        return False

    def vec3_within_yz(self, v: Vec3) -> Bool:
        """Reports whether a point is within the box's Y and Z bounds,
        inclusive (Go `Vec3WithinYZ`)."""
        if v.z() < self._min.z() or v.z() > self._max.z():
            return False
        return v.y() >= self._min.y() and v.y() <= self._max.y()

    def vec3_within_xz(self, v: Vec3) -> Bool:
        """Reports whether a point is within the box's X and Z bounds,
        inclusive (Go `Vec3WithinXZ`)."""
        if v.x() < self._min.x() or v.x() > self._max.x():
            return False
        return v.z() >= self._min.z() and v.z() <= self._max.z()

    def vec3_within_xy(self, v: Vec3) -> Bool:
        """Reports whether a point is within the box's X and Y bounds,
        inclusive (Go `Vec3WithinXY`)."""
        if v.x() < self._min.x() or v.x() > self._max.x():
            return False
        return v.y() >= self._min.y() and v.y() <= self._max.y()

    def x_offset(self, nearby: BBox, delta_x: Float64) -> Float64:
        """Clips a movement on the X axis so that this box does not move into
        `nearby` (Go `XOffset`)."""
        if (
            self._max.y() <= nearby._min.y()
            or self._min.y() >= nearby._max.y()
            or self._max.z() <= nearby._min.z()
            or self._min.z() >= nearby._max.z()
        ):
            return delta_x
        var d = delta_x
        if d > 0 and self._max.x() <= nearby._min.x():
            d = min(d, nearby._min.x() - self._max.x())
        elif d < 0 and self._min.x() >= nearby._max.x():
            d = max(d, nearby._max.x() - self._min.x())
        return d

    def y_offset(self, nearby: BBox, delta_y: Float64) -> Float64:
        """Clips a movement on the Y axis so that this box does not move into
        `nearby` (Go `YOffset`)."""
        if (
            self._max.x() <= nearby._min.x()
            or self._min.x() >= nearby._max.x()
            or self._max.z() <= nearby._min.z()
            or self._min.z() >= nearby._max.z()
        ):
            return delta_y
        var d = delta_y
        if d > 0 and self._max.y() <= nearby._min.y():
            d = min(d, nearby._min.y() - self._max.y())
        if d < 0 and self._min.y() >= nearby._max.y():
            d = max(d, nearby._max.y() - self._min.y())
        return d

    def z_offset(self, nearby: BBox, delta_z: Float64) -> Float64:
        """Clips a movement on the Z axis so that this box does not move into
        `nearby` (Go `ZOffset`)."""
        if (
            self._max.x() <= nearby._min.x()
            or self._min.x() >= nearby._max.x()
            or self._max.y() <= nearby._min.y()
            or self._min.y() >= nearby._max.y()
        ):
            return delta_z
        var d = delta_z
        if d > 0 and self._max.z() <= nearby._min.z():
            d = min(d, nearby._min.z() - self._max.z())
        if d < 0 and self._min.z() >= nearby._max.z():
            d = max(d, nearby._max.z() - self._min.z())
        return d

    def corners(self) -> List[Vec3]:
        """Returns the eight corners of the box (Go `Corners`)."""
        var lo = self._min
        var hi = self._max
        return [
            lo,
            hi,
            Vec3(lo.x(), lo.y(), hi.z()),
            Vec3(lo.x(), hi.y(), lo.z()),
            Vec3(lo.x(), hi.y(), hi.z()),
            Vec3(hi.x(), hi.y(), lo.z()),
            Vec3(hi.x(), lo.y(), hi.z()),
            Vec3(hi.x(), lo.y(), lo.z()),
        ]

    def mul(self, val: Float64) -> BBox:
        """Scales both corners (Go `Mul`)."""
        return BBox(self._min.mul(val), self._max.mul(val))

    def volume(self) -> Float64:
        """Returns the volume of the box (Go `Volume`)."""
        return self.height() * self.length() * self.width()

    def write_to(self, mut writer: Some[Writer]):
        """Writes the box as `{min max}`."""
        writer.write("{", self._min, " ", self._max, "}")


def any_intersections(boxes: List[BBox], search: BBox) -> Bool:
    """Reports whether any box overlaps `search` at all (Go
    `AnyIntersections`, with no epsilon)."""
    for b in boxes:
        if b._intersects_with(search, 0):
            return True
    return False
