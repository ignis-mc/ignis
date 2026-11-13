"""Parsing and formatting of the values `interop/world` writes: floats as
the hex of their IEEE bits, ints in decimal, bools as 0 and 1."""

from ignis.block.cube.bbox import BBox
from ignis.block.cube.pos import Pos
from ignis.mgl64 import Vec3
from std.memory import bitcast


def parse_f64(s: StringSlice) raises -> Float64:
    """Parses 16 hex digits of IEEE bits."""
    var bits = UInt64(0)
    for b in s.as_bytes():
        var d: UInt64
        if b >= UInt8(ord("0")) and b <= UInt8(ord("9")):
            d = UInt64(b - UInt8(ord("0")))
        elif b >= UInt8(ord("a")) and b <= UInt8(ord("f")):
            d = UInt64(b - UInt8(ord("a"))) + 10
        else:
            raise Error(t"bad hex digit in {s}")
        bits = bits << 4 | d
    return bitcast[DType.float64](bits)


def f64(f: Float64) -> String:
    """Formats a float as 16 hex digits of its IEEE bits."""
    var bits = bitcast[DType.uint64](f)
    var s = String()
    for i in range(16):
        var nibble = Int((bits >> UInt64(60 - 4 * i)) & 0xF)
        s += String("0123456789abcdef"[byte=nibble])
    return s^


def b01(b: Bool) -> String:
    """Formats a bool as 0 or 1."""
    return "1" if b else "0"


def vec_s(v: Vec3) -> String:
    """Formats a vector as three floats."""
    return f64(v.x()) + "," + f64(v.y()) + "," + f64(v.z())


def box_s(b: BBox) -> String:
    """Formats a box as its minimum and maximum corners."""
    return vec_s(b.min()) + "," + vec_s(b.max())


def pos_s(p: Pos) -> String:
    """Formats a position as three ints."""
    return String(t"{p.x()},{p.y()},{p.z()}")


struct Tokens(Movable):
    """Comma separated tokens, consumed in order."""

    var parts: List[String]
    var i: Int

    def __init__(out self, s: StringSlice):
        self.parts = List[String]()
        if s.byte_length() > 0:
            for p in s.split(","):
                self.parts.append(String(p))
        self.i = 0

    def next(mut self) raises -> String:
        if self.i >= len(self.parts):
            raise Error("out of tokens")
        self.i += 1
        return self.parts[self.i - 1]

    def f64(mut self) raises -> Float64:
        return parse_f64(self.next())

    def int(mut self) raises -> Int:
        return Int(self.next())

    def vec(mut self) raises -> Vec3:
        var x = self.f64()
        var y = self.f64()
        var z = self.f64()
        return Vec3(x, y, z)

    def box(mut self) raises -> BBox:
        var lo = self.vec()
        var hi = self.vec()
        return BBox(lo, hi)

    def pos(mut self) raises -> Pos:
        var x = self.int()
        var y = self.int()
        var z = self.int()
        return Pos(x, y, z)


def read_lines(path: String) raises -> List[String]:
    """Returns the non-empty lines of a file."""
    var out = List[String]()
    with open(path, "r") as f:
        for line in f.read().split("\n"):
            if line.byte_length() > 0:
                out.append(String(line))
    return out^
