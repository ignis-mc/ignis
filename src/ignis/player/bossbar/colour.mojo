"""Boss bar colours, ported from Dragonfly `server/player/bossbar/colour.go`."""


@fieldwise_init
struct Colour(Equatable, ImplicitlyCopyable):
    """The colour of a boss bar (Go `bossbar.Colour`)."""

    var _c: UInt8

    comptime PINK = Colour(0)
    comptime BLUE = Colour(1)
    comptime RED = Colour(2)
    comptime GREEN = Colour(3)
    comptime YELLOW = Colour(4)
    comptime PURPLE = Colour(5)
    comptime REBECCA_PURPLE = Colour(6)
    comptime WHITE = Colour(7)

    def uint8(self) -> UInt8:
        """Returns the colour's network value (Go `Uint8`)."""
        return self._c
