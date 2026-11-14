"""Walking the blocks a ray passes through, ported from Dragonfly
`server/block/cube/trace/trace.go`.
"""

from std.math import floor, inf
from std.os import abort

from ....mgl64 import Vec3, float_equal
from ..pos import Pos, pos_from_vec3


def traverse_blocks[F: def(Pos) -> Bool](start: Vec3, end: Vec3, f: F):
    """Calls `f` for every block position the segment from `start` to `end`
    passes through, in order, until `f` returns False (Go
    `TraverseBlocks`). Aborts if `start` and `end` are the same point, as Go
    panics."""
    var dir = end.sub(start)
    if float_equal(dir.len_sqr(), 0):
        abort(
            "start and end points are the same, giving a zero direction vector"
        )
    dir = dir.normalize()
    var b = pos_from_vec3(start)
    var step = Vec3(_sign(dir.x()), _sign(dir.y()), _sign(dir.z()))
    var step_x = Int(step.x())
    var step_y = Int(step.y())
    var step_z = Int(step.z())
    var mx = _boundary(start.x(), dir.x())
    var my = _boundary(start.y(), dir.y())
    var mz = _boundary(start.z(), dir.z())
    var dx = _safe_divide(step.x(), dir.x())
    var dy = _safe_divide(step.y(), dir.y())
    var dz = _safe_divide(step.z(), dir.z())
    var r = start.sub(end).len()
    while True:
        if not f(b):
            return
        if mx < my and mx < mz:
            if mx > r:
                return
            b = Pos(b.x() + step_x, b.y(), b.z())
            mx += dx
        elif my < mz:
            if my > r:
                return
            b = Pos(b.x(), b.y() + step_y, b.z())
            my += dy
        else:
            if mz > r:
                return
            b = Pos(b.x(), b.y(), b.z() + step_z)
            mz += dz


def _safe_divide(dividend: Float64, divisor: Float64) -> Float64:
    if divisor == 0.0:
        return 0.0
    return dividend / divisor


def _boundary(start: Float64, dir: Float64) -> Float64:
    if dir == 0.0:
        return inf[DType.float64]()
    var s = start
    var d = dir
    if d < 0.0:
        s = -s
        d = -d
        if floor(s) == s:
            return 0.0
    return (1 - (s - floor(s))) / d


def _sign(f: Float64) -> Float64:
    if f > 0.0:
        return 1.0
    if f < 0.0:
        return -1.0
    return 0.0
