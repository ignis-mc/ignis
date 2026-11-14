"""Capes, ported from Dragonfly `server/player/skin/cape.go`."""


struct Cape(Copyable, Defaultable):
    """The cape of a skin (Go `skin.Cape`)."""

    var _w: Int
    var _h: Int
    var pix: List[UInt8]
    """The RGBA pixels, row by row."""

    def __init__(out self):
        """Creates an empty 0x0 cape."""
        self = Self(0, 0)

    def __init__(out self, width: Int, height: Int):
        """Creates a transparent cape (Go `NewCape`)."""
        self._w = width
        self._h = height
        self.pix = List[UInt8](length=max(width * height * 4, 0), fill=0)

    def bounds(self) -> Tuple[Int, Int]:
        """Returns the width and height (Go `Bounds().Max`)."""
        return (self._w, self._h)

    def at(self, x: Int, y: Int) -> Tuple[UInt8, UInt8, UInt8, UInt8]:
        """Returns the RGBA of a pixel (Go `At`)."""
        debug_assert(
            x >= 0 and y >= 0 and x < self._w and y < self._h,
            "pixel coordinates out of bounds",
        )
        var o = x * 4 + self._w * y * 4
        return (self.pix[o], self.pix[o + 1], self.pix[o + 2], self.pix[o + 3])
