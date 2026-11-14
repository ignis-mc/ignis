"""Block positions, ported from Dragonfly `server/block/cube/pos.go`.

Go's `Neighbours` calls a function for each neighbour and `Range3D` returns
an iterator; here they return lists.
"""

from std.math import floor

from ...mgl64 import Vec3
from .face import Face
from .range import Range


@fieldwise_init
struct Pos(Equatable, Hashable, ImplicitlyCopyable, Writable):
    """The position of a block (Go `cube.Pos`, `[3]int`)."""

    var _x: Int
    var _y: Int
    var _z: Int

    def x(self) -> Int:
        """Returns the X coordinate."""
        return self._x

    def y(self) -> Int:
        """Returns the Y coordinate."""
        return self._y

    def z(self) -> Int:
        """Returns the Z coordinate."""
        return self._z

    def out_of_bounds(self, r: Range) -> Bool:
        """Checks if the Y value is outside the range passed."""
        return self._y > r.max() or self._y < r.min()

    def add(self, pos: Pos) -> Pos:
        """Adds two positions."""
        return Pos(self._x + pos._x, self._y + pos._y, self._z + pos._z)

    def sub(self, pos: Pos) -> Pos:
        """Subtracts a position."""
        return Pos(self._x - pos._x, self._y - pos._y, self._z - pos._z)

    def vec3(self) -> Vec3:
        """Returns the position as a vector (Go `Vec3`)."""
        return Vec3(Float64(self._x), Float64(self._y), Float64(self._z))

    def vec3_middle(self) -> Vec3:
        """Returns the position with 0.5 added on both horizontal axes (Go
        `Vec3Middle`)."""
        return Vec3(
            Float64(self._x) + 0.5, Float64(self._y), Float64(self._z) + 0.5
        )

    def vec3_centre(self) -> Vec3:
        """Returns the position with 0.5 added on all axes (Go
        `Vec3Centre`)."""
        return Vec3(
            Float64(self._x) + 0.5,
            Float64(self._y) + 0.5,
            Float64(self._z) + 0.5,
        )

    def neighbours(self, r: Range) -> List[Pos]:
        """Returns the positions directly around this one that are within
        the range (Go `Neighbours`, which calls a function for each)."""
        var out = List[Pos](capacity=6)
        if self.out_of_bounds(r):
            return out^
        out.append(Pos(self._x + 1, self._y, self._z))
        out.append(Pos(self._x - 1, self._y, self._z))
        if self._y + 1 <= r.max():
            out.append(Pos(self._x, self._y + 1, self._z))
        if self._y - 1 >= r.min():
            out.append(Pos(self._x, self._y - 1, self._z))
        out.append(Pos(self._x, self._y, self._z + 1))
        out.append(Pos(self._x, self._y, self._z - 1))
        return out^

    def within(self, lo: Pos, hi: Pos) -> Bool:
        """Reports whether the position lies within a box of positions,
        inclusive (Go `Within`)."""
        return (
            self._x >= lo._x
            and self._x <= hi._x
            and self._y >= lo._y
            and self._y <= hi._y
            and self._z >= lo._z
            and self._z <= hi._z
        )

    def side(self, face: Face) -> Pos:
        """Returns the position next to this one on a face (Go `Side`)."""
        if face == Face.UP:
            return Pos(self._x, self._y + 1, self._z)
        if face == Face.DOWN:
            return Pos(self._x, self._y - 1, self._z)
        if face == Face.NORTH:
            return Pos(self._x, self._y, self._z - 1)
        if face == Face.SOUTH:
            return Pos(self._x, self._y, self._z + 1)
        if face == Face.WEST:
            return Pos(self._x - 1, self._y, self._z)
        if face == Face.EAST:
            return Pos(self._x + 1, self._y, self._z)
        return self

    def face(self, other: Pos) -> Face:
        """Returns the face of this position that `other` is on (Go `Face`)."""
        if case .Some(f) = self.neighbour_face(other):
            return f
        return Face.UP

    def neighbour_face(self, other: Pos) -> Optional[Face]:
        """Returns the face of this position that `other` is on (Go
        `NeighbourFace`)."""
        var d = other.sub(self)
        if d == Pos(0, 1, 0):
            return Face.UP
        if d == Pos(0, -1, 0):
            return Face.DOWN
        if d == Pos(0, 0, -1):
            return Face.NORTH
        if d == Pos(0, 0, 1):
            return Face.SOUTH
        if d == Pos(-1, 0, 0):
            return Face.WEST
        if d == Pos(1, 0, 0):
            return Face.EAST
        return None

    def write_to(self, mut writer: Some[Writer]):
        """Writes the position as `(x,y,z)`, as Go's `String` does."""
        writer.write("(", self._x, ",", self._y, ",", self._z, ")")


def pos_from_vec3(v: Vec3) -> Pos:
    """Returns the block position a vector is in (Go `PosFromVec3`)."""
    return Pos(Int(floor(v.x())), Int(floor(v.y())), Int(floor(v.z())))


def pos_min(p1: Pos, p2: Pos) -> Pos:
    """Returns the per-axis minimum of two positions (Go `cube.Min`)."""
    return Pos(min(p1.x(), p2.x()), min(p1.y(), p2.y()), min(p1.z(), p2.z()))


def pos_max(p1: Pos, p2: Pos) -> Pos:
    """Returns the per-axis maximum of two positions (Go `cube.Max`)."""
    return Pos(max(p1.x(), p2.x()), max(p1.y(), p2.y()), max(p1.z(), p2.z()))


def range_3d(p1: Pos, p2: Pos) -> List[Pos]:
    """Returns every position in the box spanned by two corners (Go
    `Range3D`), X outermost and Z innermost."""
    var hi = pos_max(p1, p2)
    var lo = pos_min(p1, p2)
    var out = List[Pos]()
    for x in range(lo.x(), hi.x() + 1):
        for y in range(lo.y(), hi.y() + 1):
            for z in range(lo.z(), hi.z() + 1):
                out.append(Pos(x, y, z))
    return out^
