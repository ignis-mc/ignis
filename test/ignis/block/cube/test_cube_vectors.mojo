"""Checks `ignis.block.cube` and `cube.trace` against the values
`interop/world` computed with Dragonfly (`test/data/world/cube.txt`)."""

from ignis.block.cube.axis import Axis
from ignis.block.cube.bbox import BBox, any_intersections
from ignis.block.cube.face import Face
from ignis.block.cube.orientation import Orientation, orientation_from_yaw
from ignis.block.cube.pos import Pos, pos_from_vec3, range_3d
from ignis.block.cube.rotation import Rotation
from ignis.block.cube.trace.bbox import bbox_intercept, bbox_intersects
from ignis.block.cube.trace.trace import traverse_blocks
from ignis.internal.gomath import go_cos, go_sin
from std.testing import TestSuite, assert_equal, assert_true
from support.go_values import (
    Tokens,
    b01,
    box_s,
    f64,
    pos_s,
    read_lines,
    vec_s,
)


def _compute(op: String, mut a: Tokens) raises -> String:
    if op == "box":
        return box_s(a.box())
    if op == "size":
        var b = a.box()
        return (
            f64(b.width())
            + ","
            + f64(b.height())
            + ","
            + f64(b.length())
            + ","
            + f64(b.volume())
        )
    if op == "corners":
        var out = List[String]()
        for v in a.box().corners():
            out.append(vec_s(v))
        return String(",").join(out)
    if op == "grow":
        var b = a.box()
        return box_s(b.grow(a.f64()))
    if op == "mul":
        var b = a.box()
        return box_s(b.mul(a.f64()))
    if op == "extend_towards":
        var b = a.box()
        var f = Face(a.int())
        return box_s(b.extend_towards(f, a.f64()))
    if op == "translate_towards":
        var b = a.box()
        var f = Face(a.int())
        return box_s(b.translate_towards(f, a.f64()))
    if op == "stretch":
        var b = a.box()
        var ax = Axis(a.int())
        return box_s(b.stretch(ax, a.f64()))
    if op == "grow_vec3":
        var b = a.box()
        return box_s(b.grow_vec3(a.vec()))
    if op == "extend":
        var b = a.box()
        return box_s(b.extend(a.vec()))
    if op == "translate":
        var b = a.box()
        return box_s(b.translate(a.vec()))
    if op == "within":
        var b = a.box()
        var v = a.vec()
        return (
            b01(b.vec3_within(v))
            + ","
            + b01(b.vec3_within_yz(v))
            + ","
            + b01(b.vec3_within_xz(v))
            + ","
            + b01(b.vec3_within_xy(v))
        )
    if op == "intersects":
        var b = a.box()
        var o = a.box()
        return b01(b.intersects_with(o)) + "," + b01(any_intersections([o], b))
    if op == "offset":
        var b = a.box()
        var o = a.box()
        var d = a.f64()
        return (
            f64(b.x_offset(o, d))
            + ","
            + f64(b.y_offset(o, d))
            + ","
            + f64(b.z_offset(o, d))
        )
    if op == "rotation":
        var yaw = a.f64()
        var r = Rotation(yaw, a.f64())
        var o = r.opposite()
        var n = r.neg()
        return String(
            t"{f64(o.yaw())},{f64(o.pitch())},{f64(n.yaw())},{f64(n.pitch())},"
            t"{Int(r.direction())},{Int(r.orientation())},{vec_s(r.vec3())}"
        )
    if op == "rotation_add":
        var y1 = a.f64()
        var r = Rotation(y1, a.f64())
        var y2 = a.f64()
        var s = r.add(Rotation(y2, a.f64()))
        return f64(s.yaw()) + "," + f64(s.pitch())
    if op == "orientation":
        var o = orientation_from_yaw(a.f64())
        return String(
            t"{Int(o)},{f64(o.yaw())},{Int(o.opposite())},"
            t"{Int(o.rotate_left())},{Int(o.rotate_right())}"
        )
    if op == "pos_string":
        return String(a.pos())
    if op == "pos_side":
        var p = a.pos()
        return pos_s(p.side(Face(a.int())))
    if op == "pos_face":
        var p = a.pos()
        var q = a.pos()
        var nf = p.neighbour_face(q)
        var f = nf.value() if nf else Face.UP
        return String(t"{Int(f)},{b01(Bool(nf))},{Int(p.face(q))}")
    if op == "pos_within":
        var p = a.pos()
        var lo = a.pos()
        return b01(p.within(lo, a.pos()))
    if op == "pos_from_vec3":
        return pos_s(pos_from_vec3(a.vec()))
    if op == "range3d":
        var p1 = a.pos()
        return String(len(range_3d(p1, a.pos())))
    if op == "traverse":
        var start = a.vec()
        var end = a.vec()
        var visited = List[String]()

        def visit(p: Pos) {mut visited} -> Bool:
            visited.append(pos_s(p))
            return len(visited) < 64

        traverse_blocks(start, end, visit)
        return String(";").join(visited)
    if op == "intercept":
        var b = a.box()
        var start = a.vec()
        var end = a.vec()
        if case .Some(r) = bbox_intercept(b, start, end):
            return String(
                t"1,{vec_s(r.position())},{Int(r.face())},{box_s(r.bbox())}"
            )
        return "0"
    if op == "intersects_ray":
        var b = a.box()
        var start = a.vec()
        return b01(bbox_intersects(b, start, a.vec()))
    if op == "gomath":
        var x = a.f64()
        return f64(go_sin(x)) + "," + f64(go_cos(x))
    raise Error(t"unknown op {op}")


def test_cube_matches_dragonfly() raises:
    var n = 0
    for line in read_lines("test/data/world/cube.txt"):
        var parts = line.split("\t")
        var op = String(parts[0])
        var args = Tokens(parts[1])
        var got = _compute(op, args)
        assert_equal(got, String(parts[2]), String(t"{op} {parts[1]}"))
        n += 1
    assert_true(n > 1000)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
