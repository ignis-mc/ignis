"""Height maps, ported from Dragonfly `server/world/chunk/heightmap.go`."""


struct HeightMap(Copyable, Equatable, Sized):
    """The Y of the highest light-blocking block of each column, indexed by
    `x << 4 | z` (Go `HeightMap`, `[]int16`)."""

    var _values: List[Int16]

    def __init__(out self):
        """Creates a height map of 256 zeros."""
        self._values = List[Int16](length=256, fill=0)

    def __len__(self) -> Int:
        """Returns the number of columns.

        Returns:
            256.
        """
        return len(self._values)

    def __getitem__(self, i: Int) -> Int16:
        """Returns the value at an index (`x << 4 | z`).

        Args:
            i: The index.

        Returns:
            The height.
        """
        return self._values[i]

    def at(self, x: UInt8, z: UInt8) -> Int16:
        """Returns the height of a column.

        Args:
            x: The X coordinate, 0 to 15.
            z: The Z coordinate, 0 to 15.

        Returns:
            The height.
        """
        return self._values[(Int(x) << 4) | Int(z)]

    def set(mut self, x: UInt8, z: UInt8, val: Int16):
        """Sets the height of a column.

        Args:
            x: The X coordinate, 0 to 15.
            z: The Z coordinate, 0 to 15.
            val: The height.
        """
        self._values[(Int(x) << 4) | Int(z)] = val

    def highest_neighbour(self, x: UInt8, z: UInt8) -> Int16:
        """Returns the highest value of the columns directly next to one.

        Args:
            x: The X coordinate, 0 to 15.
            z: The Z coordinate, 0 to 15.

        Returns:
            The highest neighbouring height, or `Int16.MIN` if none.
        """
        var highest = Int16.MIN
        if x != 15:
            highest = max(highest, self.at(x + 1, z))
        if x != 0:
            highest = max(highest, self.at(x - 1, z))
        if z != 15:
            highest = max(highest, self.at(x, z + 1))
        if z != 0:
            highest = max(highest, self.at(x, z - 1))
        return highest

    def __eq__(self, other: Self) -> Bool:
        """Compares two height maps.

        Args:
            other: The height map to compare with.

        Returns:
            True if every column is equal.
        """
        return self._values == other._values
