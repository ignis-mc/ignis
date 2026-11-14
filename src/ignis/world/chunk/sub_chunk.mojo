"""Sub-chunks, ported from Dragonfly `server/world/chunk/sub_chunk.go`.

The block and sky light arrays are not ported yet: they are only filled by
Dragonfly's light engine (`light.go`, `light_area.go`), which is server-side
state the client never receives, and comes with it.
"""

from .paletted_storage import PalettedStorage


struct SubChunk(Copyable, Movable):
    """A 16x16x16 cube of blocks: a stack of layers (storages), the first
    holding the blocks and the second usually water inside them."""

    var _air: UInt32
    var _storages: List[PalettedStorage]

    def __init__(out self, air: UInt32):
        """Creates an empty sub-chunk (Go `NewSubChunk`).

        Args:
            air: The runtime ID of air.
        """
        self._air = air
        self._storages = List[PalettedStorage]()

    def equals(self, s: Self) -> Bool:
        """Reports whether two sub-chunks are equal (Go `Equals`), using
        `PalettedStorage.equal` for each layer.

        Args:
            s: The sub-chunk to compare with.

        Returns:
            True if they compare equal.
        """
        if s._air != self._air or len(s._storages) != len(self._storages):
            return False
        for i in range(len(s._storages)):
            if not s._storages[i].equal(self._storages[i]):
                return False
        return True

    def empty(self) -> Bool:
        """Reports whether the sub-chunk has no layers, or a single one
        filled with air.

        Returns:
            True if the sub-chunk holds only air.
        """
        if len(self._storages) == 0:
            return True
        if len(self._storages) != 1:
            return False
        ref values = self._storages[0]._palette._values
        return len(values) == 1 and values[0] == self._air

    def layer(mut self, layer: UInt8) -> ref[self._storages[0]] PalettedStorage:
        """Returns a layer, creating it and every layer below it if needed
        (Go `Layer`).

        Args:
            layer: The layer index.

        Returns:
            The layer.
        """
        while UInt8(len(self._storages)) <= layer:
            self._storages.append(PalettedStorage.empty(self._air))
        return self._storages[Int(layer)]

    def layers(ref self) -> ref[self._storages] List[PalettedStorage]:
        """Returns all layers; there may be none.

        Returns:
            The layers.
        """
        return self._storages

    def block(self, x: UInt8, y: UInt8, z: UInt8, layer: UInt8) -> UInt32:
        """Returns the runtime ID at a position (coordinates 0 to 15).

        Args:
            x: The X coordinate.
            y: The Y coordinate.
            z: The Z coordinate.
            layer: The layer.

        Returns:
            The runtime ID; air for layers that do not exist.
        """
        if UInt8(len(self._storages)) <= layer:
            return self._air
        return self._storages[Int(layer)].at(x, y, z)

    def set_block(
        mut self, x: UInt8, y: UInt8, z: UInt8, layer: UInt8, block: UInt32
    ):
        """Sets the runtime ID at a position (coordinates 0 to 15).

        Args:
            x: The X coordinate.
            y: The Y coordinate.
            z: The Z coordinate.
            layer: The layer, created if needed.
            block: The runtime ID.
        """
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
