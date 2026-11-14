"""Colours, ported from Dragonfly `server/item/colour.go`.

`RGBA` and `SignRGBA` follow with their users.
"""

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
        """Creates a colour from its value (Go `Colour{c}`).

        Args:
            c: 0 to 15.
        """
        self._c = UInt8(c)

    def __eq__(self, other: Self) -> Bool:
        """Compares two colours.

        Args:
            other: The colour to compare with.

        Returns:
            True if both are the same colour.
        """
        return self._c == other._c

    def uint8(self) -> UInt8:
        """Returns the colour as a byte (Go `Uint8`).

        Returns:
            0 to 15.
        """
        return self._c

    def write_to(self, mut writer: Some[Writer]):
        """Writes the colour's name, such as `light_blue` (Go `String`).

        Args:
            writer: The destination.
        """
        writer.write(
            enum_name(
                (
                    "white,orange,magenta,light_blue,yellow,lime,pink,gray,"
                    "light_gray,cyan,purple,blue,brown,green,red,black"
                ),
                Int(self._c),
            )
        )

    def silver_string(self) -> String:
        """Returns the name, with `silver` for light grey (Go
        `SilverString`).

        Returns:
            The name.
        """
        if self._c == 8:
            return "silver"
        return String(self)


def colours() -> List[Colour]:
    """Returns all 16 colours in order (Go `item.Colours`).

    Returns:
        The colours.
    """
    var out = List[Colour](capacity=16)
    for i in range(16):
        out.append(Colour(i))
    return out^
