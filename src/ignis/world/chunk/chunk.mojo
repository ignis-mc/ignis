"""Chunks, ported from Dragonfly `server/world/chunk/chunk.go`.

Differences from Go:

- A chunk does not hold the block registry; `height_map` and
  `highest_light_blocker` take it as an argument.
- The light accessors (`Light`, `SkyLight`, `BlockLight`) come with the light
  engine; see `sub_chunk.mojo`.
"""

from ...block.cube.range import Range
from .block_registry import BlockRegistry
from .heightmap import HeightMap
from .palette import Palette, palette_size_for, uint32s
from .paletted_storage import PalettedStorage
from .sub_chunk import SubChunk


struct Chunk(Copyable, Movable):
    """A column of sub-chunks covering a dimension's height, with a biome
    storage per sub-chunk."""

    var _r: Range
    var _air: UInt32
    var _recalculate_height_map: Bool
    var _legacy_states: Bool
    var _height_map: HeightMap
    var _sub: List[SubChunk]
    var _biomes: List[PalettedStorage]

    def __init__[R: BlockRegistry](out self, br: R, r: Range):
        """Creates an empty chunk (Go `New`).

        Parameters:
            R: The registry type.

        Args:
            br: The finalized registry whose runtime IDs the chunk holds.
            r: The vertical range of the chunk.
        """
        self = Self(br.air_runtime_id(), r)

    def __init__(out self, air: UInt32, r: Range):
        """Creates an empty chunk given the air runtime ID.

        Args:
            air: The runtime ID of air.
            r: The vertical range of the chunk.
        """
        var n = (r.height() >> 4) + 1
        self._r = r
        self._air = air
        self._recalculate_height_map = True
        self._legacy_states = False
        self._height_map = HeightMap()
        self._sub = List[SubChunk](capacity=n)
        self._biomes = List[PalettedStorage](capacity=n)
        for _ in range(n):
            self._sub.append(SubChunk(air))
            self._biomes.append(PalettedStorage.empty(0))

    def equals(self, c: Self) -> Bool:
        """Reports whether two chunks are equal (Go `Equals`).

        Args:
            c: The chunk to compare with.

        Returns:
            True if range, air, height maps (when both are current) and
            sub-chunks match.
        """
        if (
            not self._recalculate_height_map
            and not c._recalculate_height_map
            and self._height_map != c._height_map
        ):
            return False
        if (
            c._r != self._r
            or c._air != self._air
            or len(c._sub) != len(self._sub)
        ):
            return False
        for i in range(len(c._sub)):
            if not c._sub[i].equals(self._sub[i]):
                return False
        return True

    def legacy_states(self) -> Bool:
        """Reports whether the chunk was decoded with outdated block states
        (Go `LegacyStates`).

        Returns:
            The flag.
        """
        return self._legacy_states

    def mark_states_upgraded(mut self):
        """Clears the flag `legacy_states` returns."""
        self._legacy_states = False

    def mark_legacy_states(mut self):
        """Sets the flag `legacy_states` returns."""
        self._legacy_states = True

    def range(self) -> Range:
        """Returns the vertical range of the chunk.

        Returns:
            The range passed when it was created.
        """
        return self._r

    def air(self) -> UInt32:
        """Returns the runtime ID of air used by the chunk.

        Returns:
            The air runtime ID.
        """
        return self._air

    def sub(ref self) -> ref[self._sub] List[SubChunk]:
        """Returns the sub-chunks, lowest first.

        Returns:
            The sub-chunks.
        """
        return self._sub

    def biomes(ref self) -> ref[self._biomes] List[PalettedStorage]:
        """Returns the biome storages, one per sub-chunk.

        Returns:
            The biome storages.
        """
        return self._biomes

    def block(self, x: UInt8, y: Int16, z: UInt8, layer: UInt8) -> UInt32:
        """Returns the runtime ID at a position; air where nothing is set.

        Args:
            x: The X coordinate, 0 to 15.
            y: The Y coordinate, within the range.
            z: The Z coordinate, 0 to 15.
            layer: The layer.

        Returns:
            The runtime ID.
        """
        ref sub = self._sub[Int(self.sub_index(y))]
        if sub.empty() or UInt8(len(sub._storages)) <= layer:
            return self._air
        return sub._storages[Int(layer)].at(x, UInt8(y & 0xFF), z)

    def set_block(
        mut self, x: UInt8, y: Int16, z: UInt8, layer: UInt8, block: UInt32
    ):
        """Sets the runtime ID at a position.

        Args:
            x: The X coordinate, 0 to 15.
            y: The Y coordinate, within the range.
            z: The Z coordinate, 0 to 15.
            layer: The layer.
            block: The runtime ID.
        """
        ref sub = self._sub[Int(self.sub_index(y))]
        if UInt8(len(sub._storages)) <= layer and block == self._air:
            # Missing layers already hold air.
            return
        sub.layer(layer).set(x, UInt8(y & 0xFF), z, block)
        self._recalculate_height_map = True

    def biome(self, x: UInt8, y: Int16, z: UInt8) -> UInt32:
        """Returns the biome ID at a position.

        Args:
            x: The X coordinate, 0 to 15.
            y: The Y coordinate, within the range.
            z: The Z coordinate, 0 to 15.

        Returns:
            The biome ID.
        """
        return self._biomes[Int(self.sub_index(y))].at(x, UInt8(y & 0xFF), z)

    def set_biome(mut self, x: UInt8, y: Int16, z: UInt8, biome: UInt32):
        """Sets the biome ID at a position.

        Args:
            x: The X coordinate, 0 to 15.
            y: The Y coordinate, within the range.
            z: The Z coordinate, 0 to 15.
            biome: The biome ID.
        """
        self._biomes[Int(self.sub_index(y))].set(x, UInt8(y & 0xFF), z, biome)

    def set_biome_section(mut self, y: Int16, biomes: List[UInt32]):
        """Replaces the biomes of the 16x16x16 section holding height `y`
        (Go `SetBiomeSection`).

        Args:
            y: A Y coordinate within the section.
            biomes: 64 biome IDs indexed `x*16 + y*4 + z` in quart
                coordinates (Go `[4][4][4]uint32`); each fills a 4x4x4
                cube.
        """
        debug_assert(len(biomes) == 64, "set_biome_section needs 64 biomes")
        var values = List[UInt32](capacity=64)
        var indices = List[UInt16](length=64, fill=0)
        for i in range(64):
            var index = 0
            while index < len(values) and values[index] != biomes[i]:
                index += 1
            if index == len(values):
                values.append(biomes[i])
            indices[i] = UInt16(index)
        var size = palette_size_for(len(values))
        var storage = PalettedStorage(
            List[UInt32](length=uint32s(size), fill=0), Palette(size, values^)
        )
        if size != 0:
            for x in range(16):
                for z in range(16):
                    for yy in range(16):
                        storage._set_palette_index(
                            UInt8(x),
                            UInt8(yy),
                            UInt8(z),
                            indices[(x >> 2) * 16 + (yy >> 2) * 4 + (z >> 2)],
                        )
        self._biomes[Int(self.sub_index(y))] = storage^

    def highest_light_blocker[
        R: BlockRegistry
    ](self, br: R, x: UInt8, z: UInt8) -> Int16:
        """Returns the Y of the highest block in a column that blocks all
        light, or the minimum height if there is none.

        Parameters:
            R: The registry type.

        Args:
            br: The registry, for the light filtering of each block.
            x: The X coordinate, 0 to 15.
            z: The Z coordinate, 0 to 15.

        Returns:
            The Y coordinate.
        """
        return self._highest_light_blocker(br, x, z, False)

    def _highest_light_blocker[
        R: BlockRegistry
    ](self, br: R, x: UInt8, z: UInt8, add_one: Bool) -> Int16:
        var plus = Int16(1) if add_one else Int16(0)
        var index = len(self._sub) - 1
        while index >= 0:
            ref sub = self._sub[index]
            if not sub.empty():
                ref storage = sub._storages[0]
                for y in range(15, -1, -1):
                    if br.filtering_block(storage.at(x, UInt8(y), z)) == 15:
                        return (Int16(y) | self.sub_y(Int16(index))) + plus
            index -= 1
        return Int16(self._r.min())

    def highest_block(self, x: UInt8, z: UInt8) -> Int16:
        """Returns the Y of the highest non-air block in a column, or the
        minimum height if there is none.

        Args:
            x: The X coordinate, 0 to 15.
            z: The Z coordinate, 0 to 15.

        Returns:
            The Y coordinate.
        """
        var index = len(self._sub) - 1
        while index >= 0:
            ref sub = self._sub[index]
            if not sub.empty():
                ref storage = sub._storages[0]
                for y in range(15, -1, -1):
                    if storage.at(x, UInt8(y), z) != self._air:
                        return Int16(y) | self.sub_y(Int16(index))
            index -= 1
        return Int16(self._r.min())

    def height_map[R: BlockRegistry](mut self, br: R) -> HeightMap:
        """Returns the height map, recalculating it if blocks changed since
        the last call (Go `HeightMap`).

        Each column holds one above its highest fully light-blocking block,
        or the minimum height.

        Parameters:
            R: The registry type.

        Args:
            br: The registry, for the light filtering of each block.

        Returns:
            A copy of the height map.
        """
        if self._recalculate_height_map:
            for x in range(16):
                for z in range(16):
                    var h = self._highest_light_blocker(
                        br, UInt8(x), UInt8(z), True
                    )
                    self._height_map.set(UInt8(x), UInt8(z), h)
            self._recalculate_height_map = False
        return self._height_map.copy()

    def compact(mut self):
        """Compacts every sub-chunk (Go `Compact`). Meant to run before the
        chunk is saved."""
        for i in range(len(self._sub)):
            self._sub[i].compact()

    def sub_chunk(ref self, y: Int16) -> ref[self._sub[0]] SubChunk:
        """Returns the sub-chunk holding a Y coordinate (Go `SubChunk`).

        Args:
            y: The Y coordinate, within the range.

        Returns:
            The sub-chunk.
        """
        return self._sub[Int(self.sub_index(y))]

    def sub_index(self, y: Int16) -> Int16:
        """Returns the index of the sub-chunk holding a Y coordinate.

        Args:
            y: The Y coordinate.

        Returns:
            `(y - min) >> 4`.
        """
        return (y - Int16(self._r.min())) >> 4

    def sub_y(self, index: Int16) -> Int16:
        """Returns the lowest Y coordinate of a sub-chunk.

        Args:
            index: The sub-chunk index.

        Returns:
            `(index << 4) + min`.
        """
        return (index << 4) + Int16(self._r.min())

    def highest_filled_sub_chunk(self) -> UInt16:
        """Returns the number of sub-chunks up to and including the highest
        one holding blocks, or 0 if all are empty.

        Returns:
            The count.
        """
        var i = len(self._sub) - 1
        while i >= 0:
            if not self._sub[i].empty():
                return UInt16(i + 1)
            i -= 1
        return 0
