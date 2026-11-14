"""Sub-chunks, ported from Dragonfly `server/world/chunk/sub_chunk.go`.

Go shares two 2048-byte slices, `fullLight` and `noLight`, between every
sub-chunk whose light is uniform and copies one on the first write. Here a
`LightArray` with no bytes stands for such a shared slice and keeps the
byte it repeats.
"""

from .paletted_storage import PalettedStorage


struct LightArray(Copyable, Movable):
    """The light levels of a sub-chunk as 4096 nibbles (Go `[]uint8` of
    2048 bytes), indexed by `x << 8 | z << 4 | y`."""

    var _data: List[UInt8]
    var _fill: UInt8

    def __init__(out self, fill: UInt8 = 0):
        """Creates a uniform array repeating a byte (0x00 or 0xFF)."""
        self._data = List[UInt8]()
        self._fill = fill

    def shared(self) -> Bool:
        """Reports whether the array still stands for a shared uniform slice
        (Go `&light[0] == noLightPtr` or `fullLightPtr`)."""
        return len(self._data) == 0

    def same_shared(self, other: Self) -> Bool:
        """Reports whether both arrays stand for the same shared slice."""
        return self.shared() and other.shared() and self._fill == other._fill

    @always_inline
    def get(self, index: Int) -> UInt8:
        """Returns the level at an index."""
        if len(self._data) == 0:
            return self._fill & 0xF
        var b = self._data.unsafe_get(index >> 1)
        return (b >> UInt8((index & 1) << 2)) & 0xF

    @always_inline
    def set(mut self, index: Int, level: UInt8):
        """Sets the level at an index, copying a shared array first."""
        if len(self._data) == 0:
            self._data = List[UInt8](length=2048, fill=self._fill)
        var i = index >> 1
        var bit = UInt8((index & 1) << 2)
        ref b = self._data.unsafe_get(i)
        b = (b & (0xF0 >> bit)) | (level << bit)

    def bytes(self) -> List[UInt8]:
        """Returns the 2048 bytes of the array."""
        if len(self._data) == 0:
            return List[UInt8](length=2048, fill=self._fill)
        return self._data.copy()


@always_inline
def light_index(x: UInt8, y: UInt8, z: UInt8) -> Int:
    """Returns the index of a position in a `LightArray`."""
    return (Int(x) << 8) | (Int(z) << 4) | Int(y)


struct SubChunk(Copyable, Movable):
    """A 16x16x16 cube of blocks: a stack of layers (storages), the first
    holding the blocks and the second usually water inside them."""

    var _air: UInt32
    var _storages: List[PalettedStorage]
    var _block_light: LightArray
    var _sky_light: LightArray

    def __init__(out self, air: UInt32):
        """Creates an empty sub-chunk (Go `NewSubChunk`); its light is 0
        until the chunk is lit."""
        self._air = air
        self._storages = List[PalettedStorage]()
        self._block_light = LightArray()
        self._sky_light = LightArray()

    def equals(self, s: Self) -> Bool:
        """Reports whether two sub-chunks are equal (Go `Equals`), using
        `PalettedStorage.equal` for each layer."""
        if s._air != self._air or len(s._storages) != len(self._storages):
            return False
        for i in range(len(s._storages)):
            if not s._storages[i].equal(self._storages[i]):
                return False
        return True

    def empty(self) -> Bool:
        """Reports whether the sub-chunk has no layers, or a single one
        filled with air."""
        if len(self._storages) == 0:
            return True
        if len(self._storages) != 1:
            return False
        ref values = self._storages[0]._palette._values
        return len(values) == 1 and values[0] == self._air

    def layer(mut self, layer: UInt8) -> ref[self._storages[0]] PalettedStorage:
        """Returns a layer, creating it and every layer below it if needed
        (Go `Layer`)."""
        while UInt8(len(self._storages)) <= layer:
            self._storages.append(PalettedStorage.empty(self._air))
        return self._storages[Int(layer)]

    def layers(ref self) -> ref[self._storages] List[PalettedStorage]:
        """Returns all layers; there may be none."""
        return self._storages

    def block(self, x: UInt8, y: UInt8, z: UInt8, layer: UInt8) -> UInt32:
        """Returns the runtime ID at a position (coordinates 0 to 15)."""
        if UInt8(len(self._storages)) <= layer:
            return self._air
        return self._storages[Int(layer)].at(x, y, z)

    def set_block(
        mut self, x: UInt8, y: UInt8, z: UInt8, layer: UInt8, block: UInt32
    ):
        """Sets the runtime ID at a position (coordinates 0 to 15)."""
        self.layer(layer).set(x, y, z, block)

    def set_block_light(mut self, x: UInt8, y: UInt8, z: UInt8, level: UInt8):
        """Sets the block light at a position (coordinates 0 to 15)."""
        self._block_light.set(light_index(x, y, z), level)

    def block_light(self, x: UInt8, y: UInt8, z: UInt8) -> UInt8:
        """Returns the block light at a position (coordinates 0 to 15)."""
        return self._block_light.get(light_index(x, y, z))

    def set_sky_light(mut self, x: UInt8, y: UInt8, z: UInt8, level: UInt8):
        """Sets the sky light at a position (coordinates 0 to 15)."""
        self._sky_light.set(light_index(x, y, z), level)

    def sky_light(self, x: UInt8, y: UInt8, z: UInt8) -> UInt8:
        """Returns the sky light at a position (coordinates 0 to 15)."""
        return self._sky_light.get(light_index(x, y, z))

    def block_light_array(ref self) -> ref[self._block_light] LightArray:
        """Returns the block light array."""
        return self._block_light

    def sky_light_array(ref self) -> ref[self._sky_light] LightArray:
        """Returns the sky light array."""
        return self._sky_light

    def clear_light(mut self):
        """Drops the light arrays, leaving every level 0 (for chunks handed
        to a provider, which does not store light)."""
        self._block_light = LightArray()
        self._sky_light = LightArray()

    def compact(mut self):
        """Compacts every layer and drops layers holding only air (Go
        `compact`)."""
        var kept = List[PalettedStorage](capacity=len(self._storages))
        for i in range(len(self._storages)):
            self._storages[i].compact()
            ref values = self._storages[i]._palette._values
            if len(values) == 1 and values[0] == self._air:
                continue
            kept.append(self._storages[i].copy())
        self._storages = kept^
