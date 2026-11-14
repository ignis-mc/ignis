"""Block faces, ported from Dragonfly `server/block/cube/face.go`."""

from .axis import Axis
from .direction import Direction


struct Face(Equatable, ImplicitlyCopyable, Intable, Writable):
    """A face of a block (Go `cube.Face`, an `int`)."""

    var _v: UInt8

    comptime DOWN = Face(0)
    """Go `cube.FaceDown`."""
    comptime UP = Face(1)
    """Go `cube.FaceUp`."""
    comptime NORTH = Face(2)
    """Go `cube.FaceNorth`."""
    comptime SOUTH = Face(3)
    """Go `cube.FaceSouth`."""
    comptime WEST = Face(4)
    """Go `cube.FaceWest`."""
    comptime EAST = Face(5)
    """Go `cube.FaceEast`."""

    def __init__(out self, v: Int):
        """Creates a face from its value (Go `cube.Face(v)`)."""
        self._v = UInt8(v)

    def __int__(self) -> Int:
        """Returns the value of the face (Go `int(f)`)."""
        return Int(self._v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two faces."""
        return self._v == other._v

    def direction(self) -> Direction:
        """Returns the direction of a horizontal face."""
        return Direction(Int(self._v) - 2)

    def opposite(self) -> Face:
        """Returns the opposite face."""
        if self == Face.UP:
            return Face.DOWN
        if self == Face.NORTH:
            return Face.SOUTH
        if self == Face.SOUTH:
            return Face.NORTH
        if self == Face.WEST:
            return Face.EAST
        if self == Face.EAST:
            return Face.WEST
        return Face.UP

    def axis(self) -> Axis:
        """Returns the axis the face is on."""
        if self == Face.EAST or self == Face.WEST:
            return Axis.X
        if self == Face.NORTH or self == Face.SOUTH:
            return Axis.Z
        return Axis.Y

    def rotate_right(self) -> Face:
        """Rotates a horizontal face 90 degrees clockwise."""
        if self == Face.NORTH:
            return Face.EAST
        if self == Face.EAST:
            return Face.SOUTH
        if self == Face.SOUTH:
            return Face.WEST
        if self == Face.WEST:
            return Face.NORTH
        return self

    def rotate_left(self) -> Face:
        """Rotates a horizontal face 90 degrees counter-clockwise."""
        if self == Face.NORTH:
            return Face.WEST
        if self == Face.EAST:
            return Face.NORTH
        if self == Face.SOUTH:
            return Face.EAST
        if self == Face.WEST:
            return Face.SOUTH
        return self

    def write_to(self, mut writer: Some[Writer]):
        """Writes the face as `down`, `up`, `north`, `south`, `west` or
        `east` (Go `String`)."""
        if self == Face.DOWN:
            writer.write("down")
        elif self == Face.UP:
            writer.write("up")
        elif self == Face.NORTH:
            writer.write("north")
        elif self == Face.SOUTH:
            writer.write("south")
        elif self == Face.WEST:
            writer.write("west")
        else:
            writer.write("east")


def faces() -> List[Face]:
    """Returns all faces: down, up, north, east, south, west (Go
    `cube.Faces`)."""
    return [Face.DOWN, Face.UP, Face.NORTH, Face.EAST, Face.SOUTH, Face.WEST]


def horizontal_faces() -> List[Face]:
    """Returns the horizontal faces: north, east, south, west (Go
    `cube.HorizontalFaces`)."""
    return [Face.NORTH, Face.EAST, Face.SOUTH, Face.WEST]
