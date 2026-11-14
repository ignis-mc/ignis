"""Paletted storage of 4096 values, ported from Dragonfly
`server/world/chunk/paletted_storage.go`.

Go reaches the index words through an `unsafe.Pointer`; here they are a
plain `List[UInt32]`, and the palette is held by value instead of through a
pointer.
"""

from .palette import Palette, palette_size_for, uint32s


def _offset(x: UInt8, y: UInt8, z: UInt8) -> Int:
    return (Int(x) << 8) | (Int(z) << 4) | Int(y)


struct PalettedStorage(Copyable, Movable):
    """A storage of 4096 values (16x16x16) as indices into a palette, using
    0, 1, 2, 3, 4, 5, 6, 8 or 16 bits per index.

    Sizes 3, 5 and 6 leave padding bits in every word and use one extra
    word, as the game's format does.
    """

    var _bits_per_index: UInt16
    var _filled_bits_per_index: UInt16
    var _index_mask: UInt32
    var _palette: Palette
    var _indices: List[UInt32]

    def __init__(out self, var indices: List[UInt32], var palette: Palette):
        """Creates a storage from index words and a palette (Go
        `newPalettedStorage`); the bits per index follow from the number of
        words.

        Args:
            indices: The index words: 0, or `uint32s(size)` of them.
            palette: The palette.
        """
        var bits = UInt16(len(indices) // 32 // 4)
        self._bits_per_index = bits
        self._index_mask = (UInt32(1) << UInt32(bits)) - 1
        self._filled_bits_per_index = 0
        if bits != 0:
            self._filled_bits_per_index = 32 // bits * bits
        self._palette = palette^
        self._indices = indices^

    @staticmethod
    def empty(v: UInt32) -> Self:
        """Creates a storage filled with one value (Go `emptyStorage`).

        Args:
            v: The value.

        Returns:
            A storage with 0 bits per index.
        """
        return Self(List[UInt32](), Palette(0, [v]))

    def palette(ref self) -> ref[self._palette] Palette:
        """Returns the palette of the storage.

        Returns:
            The palette.
        """
        return self._palette

    def bits_per_index(self) -> UInt16:
        """Returns the bits used per index.

        Returns:
            0, 1, 2, 3, 4, 5, 6, 8 or 16.
        """
        return self._bits_per_index

    def indices(ref self) -> ref[self._indices] List[UInt32]:
        """Returns the index words, as encoded on disk and on the network.

        Returns:
            The words.
        """
        return self._indices

    def at(self, x: UInt8, y: UInt8, z: UInt8) -> UInt32:
        """Returns the value at a position; coordinates are taken modulo 16.

        Args:
            x: The X coordinate.
            y: The Y coordinate.
            z: The Z coordinate.

        Returns:
            The value.
        """
        return self._palette.value(self._palette_index(x & 15, y & 15, z & 15))

    def palette_index(self, x: UInt8, y: UInt8, z: UInt8) -> UInt16:
        """Returns the palette index stored at a position (Go
        `PaletteIndex`).

        Args:
            x: The X coordinate.
            y: The Y coordinate.
            z: The Z coordinate.

        Returns:
            The index into the palette.
        """
        return self._palette_index(x & 15, y & 15, z & 15)

    def set(mut self, x: UInt8, y: UInt8, z: UInt8, v: UInt32):
        """Sets the value at a position, growing the palette and the storage
        as needed.

        Args:
            x: The X coordinate.
            y: The Y coordinate.
            z: The Z coordinate.
            v: The value.
        """
        var index = self._palette.index(v)
        if index == -1:
            index = self._add_new(v)
        self._set_palette_index(x & 15, y & 15, z & 15, UInt16(index))

    def equal(self, other: Self) -> Bool:
        """Compares two storages as Dragonfly does (Go `Equal`).

        Storages with 0 bits per index, or whose first palette value is 0,
        never compare equal. This only decides when a biome storage is
        written as "same as the previous one", and keeping it gives the same
        bytes as Dragonfly.

        Args:
            other: The storage to compare with.

        Returns:
            True if both have the same index words and palette values.
        """
        if len(self._indices) == 0 or len(other._indices) == 0:
            return False
        if self._palette._values[0] == 0 or other._palette._values[0] == 0:
            return False
        return (
            self._indices == other._indices
            and self._palette._values == other._palette._values
        )

    def _add_new(mut self, v: UInt32) -> Int16:
        var added = self._palette.add(v)
        if added[1]:
            self._resize(self._palette._size)
        return added[0]

    def _palette_index(self, x: UInt8, y: UInt8, z: UInt8) -> UInt16:
        if self._bits_per_index == 0:
            return 0
        var offset = _offset(x, y, z) * Int(self._bits_per_index)
        var filled = Int(self._filled_bits_per_index)
        var w = self._indices[offset // filled]
        return UInt16((w >> UInt32(offset % filled)) & self._index_mask)

    def _set_palette_index(mut self, x: UInt8, y: UInt8, z: UInt8, i: UInt16):
        if self._bits_per_index == 0:
            return
        var offset = _offset(x, y, z) * Int(self._bits_per_index)
        var filled = Int(self._filled_bits_per_index)
        var word = offset // filled
        var bit = UInt32(offset % filled)
        self._indices[word] = (
            self._indices[word] & ~(self._index_mask << bit)
        ) | (UInt32(i) << bit)

    def _resize(mut self, new_size: UInt8):
        if UInt16(new_size) == self._bits_per_index:
            return
        # The palette is kept; only the words change width.
        var resized = PalettedStorage(
            List[UInt32](length=uint32s(new_size), fill=0),
            self._palette.copy(),
        )
        # A zero-bit storage's implicit indices already match the zeroed
        # words.
        if self._bits_per_index != 0:
            for x in range(16):
                for y in range(16):
                    for z in range(16):
                        resized._set_palette_index(
                            UInt8(x),
                            UInt8(y),
                            UInt8(z),
                            self._palette_index(UInt8(x), UInt8(y), UInt8(z)),
                        )
        self = resized^

    def compact(mut self):
        """Drops unused palette entries and shrinks the storage if possible
        (Go `compact`). Meant to run before a sub-chunk is saved.
        """
        var n = len(self._palette)
        if n == 0:
            return
        if n == 1:
            self._bits_per_index = 0
            self._filled_bits_per_index = 0
            self._index_mask = 0
            self._indices = List[UInt32]()
            self._palette._size = 0
            return

        var used = List[Bool](length=n, fill=False)
        for x in range(16):
            for y in range(16):
                for z in range(16):
                    used[
                        Int(self._palette_index(UInt8(x), UInt8(y), UInt8(z)))
                    ] = True
        var used_count = 0
        var all_used = True
        for u in used:
            if u:
                used_count += 1
            else:
                all_used = False
        var size = palette_size_for(used_count)
        if all_used and size == self._palette._size:
            return

        var values = List[UInt32](capacity=used_count)
        var conversion = List[UInt16](length=n, fill=0)
        for i in range(n):
            if used[i]:
                conversion[i] = UInt16(len(values))
                values.append(self._palette._values[i])
        var compacted = PalettedStorage(
            List[UInt32](length=uint32s(size), fill=0), Palette(size, values^)
        )
        for x in range(16):
            for y in range(16):
                for z in range(16):
                    var old = self._palette_index(UInt8(x), UInt8(y), UInt8(z))
                    compacted._set_palette_index(
                        UInt8(x), UInt8(y), UInt8(z), conversion[Int(old)]
                    )
        self = compacted^
