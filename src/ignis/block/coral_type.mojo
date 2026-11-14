"""`CoralType`, ported from Dragonfly `server/block/coral_type.go`."""

from ..internal.enum import enum_name
from ..item.colour import Colour


struct CoralType(Equatable, ImplicitlyCopyable, Writable):
    """A type of coral (Go `CoralType`)."""

    var _v: UInt8

    comptime TUBE = CoralType(0)
    """Go `TubeCoral()`."""
    comptime BRAIN = CoralType(1)
    """Go `BrainCoral()`."""
    comptime BUBBLE = CoralType(2)
    """Go `BubbleCoral()`."""
    comptime FIRE = CoralType(3)
    """Go `FireCoral()`."""
    comptime HORN = CoralType(4)
    """Go `HornCoral()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `CoralType{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def write_to(self, mut writer: Some[Writer]):
        """Writes the value's string form (Go `String`)."""
        writer.write(enum_name("tube,brain,bubble,fire,horn", Int(self._v)))

    def colour(self) -> Colour:
        """Returns the colour of the coral (Go `Colour`)."""
        if self._v == 0:
            return Colour.BLUE
        if self._v == 1:
            return Colour.PINK
        if self._v == 2:
            return Colour.PURPLE
        if self._v == 3:
            return Colour.RED
        return Colour.YELLOW


def coral_types() -> List[CoralType]:
    """Returns every coral type (Go `CoralTypes`)."""
    var out = List[CoralType](capacity=5)
    for i in range(5):
        out.append(CoralType(i))
    return out^
