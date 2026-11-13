"""Ray intersections with boxes, ported from Dragonfly
`server/block/cube/trace/bbox.go`.
"""

from ....mgl64 import Vec3, float_equal
from ..bbox import BBox
from ..face import Face


@fieldwise_init
struct BBoxResult(ImplicitlyCopyable):
    """The result of a ray hitting a box (Go `trace.BBoxResult`)."""

    var _bb: BBox
    var _pos: Vec3
    var _face: Face

    def bbox(self) -> BBox:
        """Returns the box that was hit (Go `BBox`).

        Returns:
            The box.
        """
        return self._bb

    def position(self) -> Vec3:
        """Returns the point where the ray hit the box (Go `Position`).

        Returns:
            The point.
        """
        return self._pos

    def face(self) -> Face:
        """Returns the face of the box that was hit (Go `Face`).

        Returns:
            The face.
        """
        return self._face


def bbox_intercept(bb: BBox, start: Vec3, end: Vec3) -> Optional[BBoxResult]:
    """Finds where the segment from `start` to `end` first enters a box (Go
    `BBoxIntercept`).

    Args:
        bb: The box.
        start: The start of the ray.
        end: The end of the ray.

    Returns:
        The hit, or None if the segment misses the box.
    """
    var lo = bb.min()
    var hi = bb.max()
    # Candidates in Go's order: west, east, down, up, north, south.
    var candidates = List[Optional[Vec3]](capacity=6)
    candidates.append(_on_line_x(start, end, lo.x()))
    candidates.append(_on_line_x(start, end, hi.x()))
    candidates.append(_on_line_y(start, end, lo.y()))
    candidates.append(_on_line_y(start, end, hi.y()))
    candidates.append(_on_line_z(start, end, lo.z()))
    candidates.append(_on_line_z(start, end, hi.z()))
    var faces = [
        Face.WEST,
        Face.EAST,
        Face.DOWN,
        Face.UP,
        Face.NORTH,
        Face.SOUTH,
    ]
    var best = -1
    var dist = Float64.MAX
    for i in range(6):
        if case .Some(v) = candidates[i]:
            var within: Bool
            if i < 2:
                within = bb.vec3_within_yz(v)
            elif i < 4:
                within = bb.vec3_within_xz(v)
            else:
                within = bb.vec3_within_xy(v)
            if not within:
                continue
            var d = start.sub(v).len_sqr()
            if d < dist:
                best = i
                dist = d
    if best < 0:
        return None
    return BBoxResult(bb, candidates[best].value(), faces[best])


def bbox_intersects(bb: BBox, start: Vec3, end: Vec3) -> Bool:
    """Reports whether the segment from `start` to `end` touches a box, using
    the slab method (Go `BBoxIntersects`).

    Args:
        bb: The box.
        start: The start of the ray.
        end: The end of the ray.

    Returns:
        True if the segment intersects the box.
    """
    var lo = bb.min()
    var hi = bb.max()
    var dir = end.sub(start)
    var t_min = 0.0
    var t_max = 1.0
    for axis in range(3):
        if float_equal(dir[axis], 0):
            if start[axis] < lo[axis] or start[axis] > hi[axis]:
                return False
            continue
        var inv = 1 / dir[axis]
        var t1 = (lo[axis] - start[axis]) * inv
        var t2 = (hi[axis] - start[axis]) * inv
        if t1 > t2:
            var t = t1
            t1 = t2
            t2 = t
        if t1 > t_min:
            t_min = t1
        if t2 < t_max:
            t_max = t2
        if t_min > t_max:
            return False
    return True


def _on_line_x(a: Vec3, b: Vec3, x: Float64) -> Optional[Vec3]:
    if float_equal(b.x(), a.x()):
        return None
    var f = (x - a.x()) / (b.x() - a.x())
    if f < 0 or f > 1:
        return None
    return Vec3(x, a.y() + (b.y() - a.y()) * f, a.z() + (b.z() - a.z()) * f)


def _on_line_y(a: Vec3, b: Vec3, y: Float64) -> Optional[Vec3]:
    if float_equal(a.y(), b.y()):
        return None
    var f = (y - a.y()) / (b.y() - a.y())
    if f < 0 or f > 1:
        return None
    return Vec3(a.x() + (b.x() - a.x()) * f, y, a.z() + (b.z() - a.z()) * f)


def _on_line_z(a: Vec3, b: Vec3, z: Float64) -> Optional[Vec3]:
    if float_equal(a.z(), b.z()):
        return None
    var f = (z - a.z()) / (b.z() - a.z())
    if f < 0 or f > 1:
        return None
    return Vec3(a.x() + (b.x() - a.x()) * f, a.y() + (b.y() - a.y()) * f, z)
