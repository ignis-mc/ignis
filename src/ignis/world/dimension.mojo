"""Dimensions, ported from Dragonfly `server/world/dimension.go`.

Go's `Dimension` is an interface with three vanilla implementations compared
by identity. Here it is a small value type: the vanilla dimensions are the
`OVERWORLD`, `NETHER` and `END` constants, and a custom dimension is another
`Dimension` value. The custom dimension registry is not ported yet.
"""

from ..block.cube.range import Range


@fieldwise_init
struct Dimension(Equatable, ImplicitlyCopyable, Writable):
    """A dimension of a World: its building range and the rules that differ
    between dimensions."""

    var id: Int
    """The dimension ID sent to clients (Go `DimensionID`)."""
    var name: StaticString
    """The name, as Go's `String`."""
    var _range: Range
    var _water_evaporates: Bool
    var _lava_spread_duration_ms: Int
    var _weather_cycle: Bool
    var _time_cycle: Bool

    def range(self) -> Range:
        """Returns the lowest and highest valid Y coordinates of a block."""
        return self._range

    def water_evaporates(self) -> Bool:
        """Reports whether water placed in the dimension evaporates."""
        return self._water_evaporates

    def lava_spread_duration_ms(self) -> Int:
        """Returns how long lava takes to spread one block (Go
        `LavaSpreadDuration`)."""
        return self._lava_spread_duration_ms

    def weather_cycle(self) -> Bool:
        """Reports whether the dimension has weather."""
        return self._weather_cycle

    def time_cycle(self) -> Bool:
        """Reports whether the time of day advances."""
        return self._time_cycle

    def __eq__(self, other: Self) -> Bool:
        """Compares dimensions by ID."""
        return self.id == other.id

    def write_to(self, mut writer: Some[Writer]):
        """Writes the dimension's name."""
        writer.write(self.name)


comptime OVERWORLD = Dimension(
    0, "Overworld", Range(-64, 319), False, 1500, True, True
)
"""The Overworld: building range [-64, 320), weather and a day cycle."""

comptime NETHER = Dimension(1, "Nether", Range(0, 127), True, 250, False, False)
"""The Nether: building range [0, 128), water evaporates."""

comptime END = Dimension(2, "End", Range(0, 255), False, 1500, False, False)
"""The End: building range [0, 256)."""


def dimension_by_id(id: Int) -> Optional[Dimension]:
    """Looks up a vanilla dimension by ID (Go `DimensionByID`)."""
    if id == 0:
        return OVERWORLD
    if id == 1:
        return NETHER
    if id == 2:
        return END
    return None
