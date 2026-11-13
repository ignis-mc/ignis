"""The vertical range of a dimension, ported from Dragonfly
`server/block/cube/range.go`."""


@fieldwise_init
struct Range(Equatable, ImplicitlyCopyable, Writable):
    """The height range of a Dimension in blocks (Go `cube.Range`, `[2]int`).

    Both bounds are inclusive.
    """

    var _min: Int
    var _max: Int

    def min(self) -> Int:
        """Returns the minimum Y value (Go `Range[0]`).

        Returns:
            The lowest valid Y coordinate.
        """
        return self._min

    def max(self) -> Int:
        """Returns the maximum Y value (Go `Range[1]`).

        Returns:
            The highest valid Y coordinate.
        """
        return self._max

    def height(self) -> Int:
        """Returns the difference between `max()` and `min()`.

        Returns:
            The height of the range.
        """
        return self._max - self._min

    def write_to(self, mut writer: Some[Writer]):
        """Writes the range as `[min max]`, as Go prints it.

        Args:
            writer: The destination.
        """
        writer.write("[", self._min, " ", self._max, "]")
