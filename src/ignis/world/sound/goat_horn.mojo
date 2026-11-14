"""`Horn`, ported from Dragonfly `server/world/sound/goat_horn.go`."""

from ...internal.enum import enum_name


struct Horn(Equatable, ImplicitlyCopyable):
    """A type of goat horn (Go `sound.Horn`)."""

    var _v: UInt8

    comptime PONDER = Horn(0)
    """Go `Ponder()`."""
    comptime SING = Horn(1)
    """Go `Sing()`."""
    comptime SEEK = Horn(2)
    """Go `Seek()`."""
    comptime FEEL = Horn(3)
    """Go `Feel()`."""
    comptime ADMIRE = Horn(4)
    """Go `Admire()`."""
    comptime CALL = Horn(5)
    """Go `Call()`."""
    comptime YEARN = Horn(6)
    """Go `Yearn()`."""
    comptime DREAM = Horn(7)
    """Go `Dream()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `Horn{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def name(self) -> StaticString:
        """Returns the display name (Go `Name`)."""
        return enum_name(
            "Ponder,Sing,Seek,Feel,Admire,Call,Yearn,Dream", Int(self._v)
        )


def goat_horns() -> List[Horn]:
    """Returns every goat horn (Go `GoatHorns`)."""
    var out = List[Horn](capacity=8)
    for i in range(8):
        out.append(Horn(i))
    return out^
