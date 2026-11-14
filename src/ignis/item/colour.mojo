"""Colours, ported from Dragonfly `server/item/colour.go`.

`SignRGBA` follows with its users.
"""

from ..internal.color import RGBA
from ..internal.enum import enum_name


struct Colour(Equatable, ImplicitlyCopyable, Writable):
    """One of the 16 colours of dyed blocks and items (Go `item.Colour`)."""

    var _c: UInt8

    comptime WHITE = Colour(0)
    """Go `item.ColourWhite()`."""
    comptime ORANGE = Colour(1)
    """Go `item.ColourOrange()`."""
    comptime MAGENTA = Colour(2)
    """Go `item.ColourMagenta()`."""
    comptime LIGHT_BLUE = Colour(3)
    """Go `item.ColourLightBlue()`."""
    comptime YELLOW = Colour(4)
    """Go `item.ColourYellow()`."""
    comptime LIME = Colour(5)
    """Go `item.ColourLime()`."""
    comptime PINK = Colour(6)
    """Go `item.ColourPink()`."""
    comptime GREY = Colour(7)
    """Go `item.ColourGrey()`."""
    comptime LIGHT_GREY = Colour(8)
    """Go `item.ColourLightGrey()`."""
    comptime CYAN = Colour(9)
    """Go `item.ColourCyan()`."""
    comptime PURPLE = Colour(10)
    """Go `item.ColourPurple()`."""
    comptime BLUE = Colour(11)
    """Go `item.ColourBlue()`."""
    comptime BROWN = Colour(12)
    """Go `item.ColourBrown()`."""
    comptime GREEN = Colour(13)
    """Go `item.ColourGreen()`."""
    comptime RED = Colour(14)
    """Go `item.ColourRed()`."""
    comptime BLACK = Colour(15)
    """Go `item.ColourBlack()`."""

    def __init__(out self, c: Int):
        """Creates a colour from its value (Go `Colour{c}`)."""
        self._c = UInt8(c)

    def __eq__(self, other: Self) -> Bool:
        """Compares two colours."""
        return self._c == other._c

    def uint8(self) -> UInt8:
        """Returns the colour as a byte (Go `Uint8`)."""
        return self._c

    def write_to(self, mut writer: Some[Writer]):
        """Writes the colour's name, such as `light_blue` (Go `String`)."""
        writer.write(
            enum_name(
                (
                    "white,orange,magenta,light_blue,yellow,lime,pink,gray,"
                    "light_gray,cyan,purple,blue,brown,green,red,black"
                ),
                Int(self._c),
            )
        )

    def rgba(self) -> RGBA:
        """Returns the colour as RGBA (Go `RGBA`)."""
        comptime table = (
            "f0f0f0f9801dc74ebd3ab3dafed83d80c71ff38baa474f529d9d97169c9c"
            "8932b83c44aa8354325e7c16b02e261d1d21"
        )
        var b = table.as_bytes()
        var i = Int(self._c) * 6
        return RGBA(
            _hex_byte(b[i], b[i + 1]),
            _hex_byte(b[i + 2], b[i + 3]),
            _hex_byte(b[i + 4], b[i + 5]),
            0xFF,
        )

    def silver_string(self) -> String:
        """Returns the name, with `silver` for light grey (Go
        `SilverString`)."""
        if self._c == 8:
            return "silver"
        return String(self)


def colours() -> List[Colour]:
    """Returns all 16 colours in order (Go `item.Colours`)."""
    var out = List[Colour](capacity=16)
    for i in range(16):
        out.append(Colour(i))
    return out^


def _hex_byte(hi: UInt8, lo: UInt8) -> UInt8:
    return _nibble(hi) << 4 | _nibble(lo)


def _nibble(c: UInt8) -> UInt8:
    if c >= UInt8(ord("a")):
        return c - UInt8(ord("a")) + 10
    return c - UInt8(ord("0"))


def invert_colour(c: Colour) -> Int16:
    """Returns the colour's ID inverted, as items and NBT store it (Go
    `invertColour`)."""
    return ~Int16(c.uint8()) & 0xF


def invert_colour_id(id: Int16) -> Colour:
    """Returns the colour of an inverted ID (Go `invertColourID`)."""
    return Colour(Int(~id & 0xF))
