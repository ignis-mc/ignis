"""The palette of a paletted storage, ported from Dragonfly
`server/world/chunk/palette.go`."""


def _next_size(size: UInt8) -> UInt8:
    """Returns the palette size after `size` (Go `increaseSize`); the sizes
    are 0, 1, 2, 3, 4, 5, 6, 8 and 16."""
    if size < 6:
        return size + 1
    if size == 6:
        return 8
    return 16


def padded(size: UInt8) -> Bool:
    """Reports whether storages with this many bits per index are padded
    (Go `paletteSize.padded`): sizes 3, 5 and 6 leave unused bits in every
    word and need one extra word.

    Args:
        size: The bits per index.

    Returns:
        True for 3, 5 and 6.
    """
    return size == 3 or size == 5 or size == 6


def palette_size_for(n: Int) -> UInt8:
    """Returns the smallest palette size that holds `n` values (Go
    `paletteSizeFor`).

    Args:
        n: The number of distinct values.

    Returns:
        The bits per index: 0, 1, 2, 3, 4, 5, 6, 8 or 16.
    """
    var size = UInt8(0)
    while True:
        if n <= (1 << Int(size)):
            return size
        if size == 16:
            # Should never happen: a sub-chunk has 4096 values.
            return 0
        size = _next_size(size)


def uint32s(size: UInt8) -> Int:
    """Returns how many words a storage with this palette size needs (Go
    `paletteSize.uint32s`).

    Args:
        size: The bits per index.

    Returns:
        The number of 32-bit words holding the 4096 indices.
    """
    var count = 0
    if size != 0:
        count = 4096 // (32 // Int(size))
    if padded(size):
        count += 1
    return count


struct Palette(Copyable, Equatable, Sized):
    """The distinct values of a paletted storage; the storage holds indices
    into it."""

    var _last: UInt32
    var _last_index: Int16
    var _size: UInt8
    var _values: List[UInt32]

    def __init__(out self, size: UInt8, var values: List[UInt32]):
        """Creates a palette (Go `newPalette`).

        Args:
            size: The bits per index of the storage it belongs to.
            values: The values.
        """
        self._last = UInt32.MAX
        self._last_index = 0
        self._size = size
        self._values = values^

    def __len__(self) -> Int:
        """Returns the number of values (Go `Len`).

        Returns:
            The number of values.
        """
        return len(self._values)

    def size(self) -> UInt8:
        """Returns the bits per index of the storage.

        Returns:
            The palette size.
        """
        return self._size

    def values(ref self) -> ref[self._values] List[UInt32]:
        """Returns the values.

        Returns:
            The values, in index order.
        """
        return self._values

    def add(mut self, v: UInt32) -> Tuple[Int16, Bool]:
        """Appends a value without checking if it is present (Go `Add`).

        Args:
            v: The value.

        Returns:
            The index of the value, and whether the palette grew to the
            next size.
        """
        var i = Int16(len(self._values))
        self._values.append(v)
        if self._needs_resize():
            self._size = _next_size(self._size)
            return (i, True)
        return (i, False)

    def replace[F: def(UInt32) -> UInt32](mut self, f: F):
        """Replaces every value with `f(value)` (Go `Replace`).

        Parameters:
            F: The function type.

        Args:
            f: The mapping.
        """
        self._last = UInt32.MAX
        for i in range(len(self._values)):
            self._values[i] = f(self._values[i])

    def index(mut self, runtime_id: UInt32) -> Int16:
        """Returns the index of a value, or -1 if it is absent (Go `Index`).

        Args:
            runtime_id: The value.

        Returns:
            The index, or -1.
        """
        if runtime_id == self._last:
            return self._last_index
        for i in range(len(self._values)):
            if self._values[i] == runtime_id:
                self._last = runtime_id
                self._last_index = Int16(i)
                return Int16(i)
        return -1

    def value(self, i: UInt16) -> UInt32:
        """Returns the value at an index (Go `Value`).

        Args:
            i: The index.

        Returns:
            The value.
        """
        return self._values[Int(i)]

    def _needs_resize(self) -> Bool:
        return len(self._values) > (1 << Int(self._size))

    def __eq__(self, other: Self) -> Bool:
        """Compares size and values; the lookup cache is ignored.

        Args:
            other: The palette to compare with.

        Returns:
            True if both are equal.
        """
        return self._size == other._size and self._values == other._values
