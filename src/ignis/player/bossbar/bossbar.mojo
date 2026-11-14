"""Boss bars, ported from Dragonfly `server/player/bossbar/bossbar.go`."""

from .colour import Colour


struct BossBar(Copyable):
    """A bar at the top of the screen with text and a health percentage (Go
    `bossbar.BossBar`)."""

    var _text: String
    var _health: Float64
    var _c: Colour

    def __init__(out self, text: String = ""):
        """Creates a full purple boss bar (Go `New`); the text is kept as
        given, a trailing newline too."""
        self._text = text
        self._health = 1
        self._c = Colour.PURPLE

    def text(self) -> String:
        """Returns the text (Go `Text`)."""
        return self._text

    def with_health_percentage(self, v: Float64) raises -> Self:
        """Returns a copy with the health set, 0 to 1 (Go
        `WithHealthPercentage`; Go panics outside the range)."""
        if v < 0 or v > 1:
            raise Error(
                "boss bar: value out of range: health percentage must be"
                " between 0.0 and 1.0"
            )
        var b = self.copy()
        b._health = v
        return b^

    def with_colour(self, c: Colour) -> Self:
        """Returns a copy with the colour set (Go `WithColour`)."""
        var b = self.copy()
        b._c = c
        return b^

    def health_percentage(self) -> Float64:
        """Returns the health, 0 to 1 (Go `HealthPercentage`)."""
        return self._health

    def colour(self) -> Colour:
        """Returns the colour (Go `Colour`)."""
        return self._c
