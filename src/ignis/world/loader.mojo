"""Chunk loaders, ported from Dragonfly `server/world/loader.go`.

A `Loader` tracks which chunks around a position a viewer has been sent.
Dragonfly loads chunks asynchronously and keeps a `pending` set; here the
world generates chunks on the loop thread, so a chunk is loaded and viewed
in the same `load` call and nothing is ever pending. The loader does not
hold its world or viewer (Mojo has no shared references); `load` takes both.
"""

from std.collections import Dict
from std.math import sqrt

from ..internal.mgl64 import Vec3
from .chunk.chunk import Chunk
from .dimension import Dimension
from .generator import Generator
from .position import ChunkPos
from .world import World, chunk_key, chunk_pos_from_block


trait Viewer:
    """Something that is shown the chunks a `Loader` loads (the chunk part
    of Go's `world.Viewer`)."""

    def view_chunk(mut self, pos: ChunkPos, dim: Dimension, mut c: Chunk):
        """Shows a chunk (Go `ViewChunk`).

        Args:
            pos: The position of the chunk.
            dim: The dimension of the chunk's world.
            c: The chunk; mutable so its height map can be cached.
        """
        ...


def chunk_distance(a: ChunkPos, b: ChunkPos) -> Int32:
    """Returns the rounded Euclidean distance between two chunk positions
    (Go `chunkDistance`).

    Args:
        a: The first position.
        b: The second position.

    Returns:
        The distance in chunks.
    """
    var dx = Float64(a.x()) - Float64(b.x())
    var dz = Float64(a.z()) - Float64(b.z())
    return Int32(round(sqrt(dx * dx + dz * dz)))


struct Loader(Movable):
    """Loads the chunks within a radius around a position for a viewer."""

    var _r: Int
    var _pos: ChunkPos
    var _load_queue: List[ChunkPos]
    var _loaded: Dict[Int, ChunkPos]
    var _closed: Bool

    def __init__(out self, chunk_radius: Int, pos: ChunkPos):
        """Creates a loader around a chunk (Go `NewLoader` and `world`).

        Args:
            chunk_radius: The radius in chunks.
            pos: The chunk to centre on.
        """
        self._r = chunk_radius
        self._pos = pos
        self._load_queue = List[ChunkPos]()
        self._loaded = Dict[Int, ChunkPos]()
        self._closed = False
        self._populate_load_queue()

    def radius(self) -> Int:
        """Returns the chunk radius.

        Returns:
            The radius in chunks.
        """
        return self._r

    def pos(self) -> ChunkPos:
        """Returns the chunk the loader is centred on.

        Returns:
            The centre chunk.
        """
        return self._pos

    def change_radius(mut self, new: Int):
        """Changes the radius, forgetting chunks now outside it (Go
        `ChangeRadius`).

        Args:
            new: The new radius in chunks.
        """
        self._r = new
        self._evict_unused()
        self._populate_load_queue()

    def move(mut self, pos: Vec3):
        """Moves the loader to the chunk holding a position (Go `Move`).

        Args:
            pos: The new position.
        """
        var chunk_pos = chunk_pos_from_block(pos.x, pos.z)
        if chunk_pos == self._pos:
            return
        self._pos = chunk_pos
        self._evict_unused()
        self._populate_load_queue()

    def load[
        G: Generator & Copyable & Deinitable, V: Viewer
    ](mut self, mut w: World[G], mut viewer: V, n: Int):
        """Loads and shows up to `n` queued chunks (Go `Load` and
        `viewChunk`).

        Parameters:
            G: The world's generator type.
            V: The viewer type.

        Args:
            w: The world to take the chunks from.
            viewer: The viewer to show them to.
            n: The most chunks to load.
        """
        var i = 0
        while i < n:
            if self._closed or len(self._load_queue) == 0:
                return
            var pos = self._load_queue.pop(0)
            i += 1
            var key = chunk_key(pos)
            if key in self._loaded or not self._within_load_radius(pos):
                continue
            viewer.view_chunk(pos, w.dimension(), w.chunk(pos))
            self._loaded[key] = pos

    def chunk_loaded(self, pos: ChunkPos) -> Bool:
        """Reports whether the loader has shown a chunk (Go `Chunk`'s ok).

        Args:
            pos: The chunk position.

        Returns:
            True if the chunk was shown and is still within the radius.
        """
        return chunk_key(pos) in self._loaded

    def loaded_count(self) -> Int:
        """Counts the chunks shown.

        Returns:
            The number of loaded chunks.
        """
        return len(self._loaded)

    def queued_count(self) -> Int:
        """Counts the chunks waiting to be loaded.

        Returns:
            The length of the load queue.
        """
        return len(self._load_queue)

    def close(mut self):
        """Forgets every chunk and stops loading (Go `Close`)."""
        self._loaded = Dict[Int, ChunkPos]()
        self._load_queue = List[ChunkPos]()
        self._closed = True

    def _evict_unused(mut self):
        var keep = Dict[Int, ChunkPos]()
        for item in self._loaded.items():
            if self._within_load_radius(item.value):
                keep[item.key] = item.value
        self._loaded = keep^

    def _within_load_radius(self, pos: ChunkPos) -> Bool:
        return chunk_distance(pos, self._pos) <= Int32(self._r)

    def _populate_load_queue(mut self):
        var r = Int32(self._r)
        var queue = List[List[ChunkPos]]()
        for _ in range(Int(r) + 1):
            queue.append(List[ChunkPos]())
        var x = -r
        while x <= r:
            var z = -r
            while z <= r:
                var pos = ChunkPos(x + self._pos.x(), z + self._pos.z())
                var dist = chunk_distance(pos, self._pos)
                z += 1
                if dist > r or chunk_key(pos) in self._loaded:
                    continue
                queue[Int(dist)].append(pos)
            x += 1
        self._load_queue.clear()
        for ring in queue:
            for pos in ring:
                self._load_queue.append(pos)
