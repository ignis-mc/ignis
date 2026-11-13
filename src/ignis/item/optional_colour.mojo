"""Optional colours, ported from Dragonfly `server/item/optional_colour.go`.
"""

from .colour import Colour


struct OptionalColour(Equatable, ImplicitlyCopyable):
    """A colour or no colour, as candles have (Go `item.OptionalColour`,
    a `uint8` that is 0 for none and the colour plus 1 otherwise)."""

    var _oc: UInt8

    comptime NONE = OptionalColour(0)
    """No colour (Go `OptionalColour(0)`)."""

    def __init__(out self, v: Int):
        """Creates the value from its byte (Go `OptionalColour(v)`).

        Args:
            v: 0 for none, the colour plus 1 otherwise.
        """
        self._oc = UInt8(v)

    def __init__(out self, c: Colour):
        """Wraps a colour (Go `NewOptionalColour`).

        Args:
            c: The colour.
        """
        self._oc = c.uint8() + 1

    def __eq__(self, other: Self) -> Bool:
        """Compares two values.

        Args:
            other: The value to compare with.

        Returns:
            True if both hold the same colour or none.
        """
        return self._oc == other._oc

    def colour(self) -> Optional[Colour]:
        """Returns the colour (Go `Colour`).

        Returns:
            The colour, or None.
        """
        if self._oc == 0:
            return None
        return Colour(Int(self._oc) - 1)

    def uint8(self) -> UInt8:
        """Returns the value as a byte (Go `Uint8`).

        Returns:
            0 for none, the colour plus 1 otherwise.
        """
        return self._oc

    def prepend(self, s: StringSlice) -> String:
        """Prefixes a name with the colour (Go `Prepend`).

        Args:
            s: The name.

        Returns:
            `colour_name`, or the name unchanged without a colour.
        """
        if case .Some(c) = self.colour():
            return String(t"{c}_{s}")
        return String(s)


def optional_colours() -> List[OptionalColour]:
    """Returns no colour followed by the 16 colours (Go `OptionalColours`).

    Returns:
        The 17 values.
    """
    var out = List[OptionalColour](capacity=17)
    for i in range(17):
        out.append(OptionalColour(i))
    return out^
