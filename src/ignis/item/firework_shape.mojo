"""`FireworkShape`, ported from Dragonfly `server/item/firework_shape.go`."""

from ..internal.enum import enum_name


struct FireworkShape(Equatable, ImplicitlyCopyable, Writable):
    """A shape of a firework explosion (Go `FireworkShape`)."""

    var _v: UInt8

    comptime SMALL_SPHERE = FireworkShape(0)
    """Go `FireworkShapeSmallSphere()`."""
    comptime HUGE_SPHERE = FireworkShape(1)
    """Go `FireworkShapeHugeSphere()`."""
    comptime STAR = FireworkShape(2)
    """Go `FireworkShapeStar()`."""
    comptime CREEPER_HEAD = FireworkShape(3)
    """Go `FireworkShapeCreeperHead()`."""
    comptime BURST = FireworkShape(4)
    """Go `FireworkShapeBurst()`."""

    def __init__(out self, v: Int):
        """Creates the shape with value `v` (0 to 4)."""
        self._v = UInt8(v)

    def __init__(out self):
        """Creates a small sphere (Go `FireworkShape{}`)."""
        self._v = 0

    def __eq__(self, other: Self) -> Bool:
        """Compares two shapes."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the shape as a byte (Go `Uint8`)."""
        return self._v

    def name(self) -> StaticString:
        """Returns the display name of the shape (Go `Name`)."""
        return enum_name(
            "Small Sphere,Huge Sphere,Star,Creeper Head,Burst", Int(self._v)
        )

    def write_to(self, mut writer: Some[Writer]):
        """Writes the shape's identifier, such as `small_sphere` (Go
        `String`)."""
        writer.write(
            enum_name(
                "small_sphere,huge_sphere,star,creeper_head,burst",
                Int(self._v),
            )
        )


def firework_shapes() -> List[FireworkShape]:
    """Returns every firework shape (Go `FireworkShapes`)."""
    var out = List[FireworkShape](capacity=5)
    for i in range(5):
        out.append(FireworkShape(i))
    return out^
