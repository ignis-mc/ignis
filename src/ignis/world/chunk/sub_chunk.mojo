"""Sub-chunks, ported from Dragonfly `server/world/chunk/sub_chunk.go`.

The light arrays are filled by the light engine (`light.mojo`). Go starts
them as shared all-dark or all-lit arrays and copies one on its first write;
here a sub-chunk keeps a flag for that state and allocates its own array on
the first write.
"""

from .paletted_storage import PalettedStorage

comptime LIGHT_UNSET: UInt8 = 0
"""The light was never calculated (Go's empty slice)."""
comptime LIGHT_NONE: UInt8 = 1
"""Every value is 0 (Go's shared `noLight`)."""
comptime LIGHT_FULL: UInt8 = 2
"""Every value is 15 (Go's shared `fullLight`)."""
comptime LIGHT_OWN: UInt8 = 3
"""The sub-chunk has its own array."""


struct SubChunk(Copyable, Movable):
    """A 16x16x16 cube of blocks: a stack of layers (storages), the first
    holding the blocks and the second usually water inside them."""

    var _air: UInt32
    var _storages: List[PalettedStorage]
    var _block_light: List[UInt8]
    var _sky_light: List[UInt8]
    var _block_kind: UInt8
    var _sky_kind: UInt8

    def __init__(out self, air: UInt32):
        """Creates an empty sub-chunk (Go `NewSubChunk`)."""
        self._air = air
        self._storages = List[PalettedStorage]()
        self._block_light = List[UInt8]()
        self._sky_light = List[UInt8]()
        self._block_kind = LIGHT_UNSET
        self._sky_kind = LIGHT_UNSET

    def reset_light(mut self, sky: UInt8, block: UInt8):
        """Sets both light arrays to a uniform state (`LIGHT_NONE` or
        `LIGHT_FULL`), as Go assigns its shared arrays."""
        self._sky_kind = sky
        self._block_kind = block
        self._sky_light = List[UInt8]()
        self._block_light = List[UInt8]()

    def light_kind(self, sky: Int) -> UInt8:
        """Returns the state of the sky light (`sky == 0`) or block light
        array."""
        return self._sky_kind if sky == 0 else self._block_kind

    def block_light(self, x: UInt8, y: UInt8, z: UInt8) -> UInt8:
        """Returns the block light at a position (Go `BlockLight`)."""
        return _get_light(self._block_light, self._block_kind, x, y, z)

    def set_block_light(mut self, x: UInt8, y: UInt8, z: UInt8, level: UInt8):
        """Sets the block light at a position (Go `SetBlockLight`)."""
        _set_light(self._block_light, self._block_kind, x, y, z, level)

    def sky_light(self, x: UInt8, y: UInt8, z: UInt8) -> UInt8:
        """Returns the sky light at a position (Go `SkyLight`)."""
        return _get_light(self._sky_light, self._sky_kind, x, y, z)

    def set_sky_light(mut self, x: UInt8, y: UInt8, z: UInt8, level: UInt8):
        """Sets the sky light at a position (Go `SetSkyLight`)."""
        _set_light(self._sky_light, self._sky_kind, x, y, z, level)

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


def _get_light(
    light: List[UInt8], kind: UInt8, x: UInt8, y: UInt8, z: UInt8
) -> UInt8:
    if kind == LIGHT_OWN:
        var index = (Int(x) << 8) | (Int(z) << 4) | Int(y)
        return (light[index >> 1] >> UInt8((index & 1) << 2)) & 0xF
    if kind == LIGHT_FULL:
        return 15
    return 0


def _set_light(
    mut light: List[UInt8],
    mut kind: UInt8,
    x: UInt8,
    y: UInt8,
    z: UInt8,
    level: UInt8,
):
    if kind != LIGHT_OWN:
        # Copy on the first write.
        var fill = UInt8(0xFF) if kind == LIGHT_FULL else UInt8(0)
        light = List[UInt8](length=2048, fill=fill)
        kind = LIGHT_OWN
    var index = (Int(x) << 8) | (Int(z) << 4) | Int(y)
    var i = index >> 1
    var bit = UInt8((index & 1) << 2)
    light[i] = (light[i] & (0xF0 >> bit)) | (level << bit)
