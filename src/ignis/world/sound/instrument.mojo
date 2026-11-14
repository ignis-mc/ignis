"""`Instrument`, ported from Dragonfly `server/world/sound/instrument.go`."""


struct Instrument(Equatable, ImplicitlyCopyable):
    """An instrument of a note block (Go `sound.Instrument`)."""

    var _v: UInt8

    comptime PIANO = Instrument(0)
    """Go `Piano()`."""
    comptime BASS_DRUM = Instrument(1)
    """Go `BassDrum()`."""
    comptime SNARE = Instrument(2)
    """Go `Snare()`."""
    comptime CLICKS_AND_STICKS = Instrument(3)
    """Go `ClicksAndSticks()`."""
    comptime BASS = Instrument(4)
    """Go `Bass()`."""
    comptime FLUTE = Instrument(5)
    """Go `Flute()`."""
    comptime BELL = Instrument(6)
    """Go `Bell()`."""
    comptime GUITAR = Instrument(7)
    """Go `Guitar()`."""
    comptime CHIMES = Instrument(8)
    """Go `Chimes()`."""
    comptime XYLOPHONE = Instrument(9)
    """Go `Xylophone()`."""
    comptime IRON_XYLOPHONE = Instrument(10)
    """Go `IronXylophone()`."""
    comptime COW_BELL = Instrument(11)
    """Go `CowBell()`."""
    comptime DIDGERIDOO = Instrument(12)
    """Go `Didgeridoo()`."""
    comptime BIT = Instrument(13)
    """Go `Bit()`."""
    comptime BANJO = Instrument(14)
    """Go `Banjo()`."""
    comptime PLING = Instrument(15)
    """Go `Pling()`."""

    def __init__(out self, v: Int):
        """Creates the value with index `v` (Go `Instrument{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two values."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`)."""
        return self._v

    def int32(self) -> Int32:
        """Returns the instrument as an int32 (Go `Int32`)."""
        return Int32(self._v)


def instruments() -> List[Instrument]:
    """Returns every instrument (no Go counterpart)."""
    var out = List[Instrument](capacity=16)
    for i in range(16):
        out.append(Instrument(i))
    return out^
