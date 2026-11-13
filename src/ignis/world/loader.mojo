"""Loaders, ported from Dragonfly `server/world/loader.go`.

A loader loads the chunks around a position for its `Viewer`, nearest
first, and moves with it. In Go a `Loader` is an object the session holds,
pointing at its world. Here the world owns its loaders, keyed by a
`LoaderID`, because it must reach their viewers whenever something
changes; Go's loader methods are `World` methods taking the ID:

| Go | Ignis |
| --- | --- |
| `NewLoader(r, w, v)` | `w.add_loader(r, v^) -> LoaderID` |
| `l.Move(tx, pos)` | `w.move_loader(id, pos)` |
| `l.Load(tx, n)` | `w.load(id, n)` |
| `l.ChangeRadius(tx, r)` | `w.change_loader_radius(id, r)` |
| `l.Chunk(pos)` | `w.loader_has_chunk(id, pos)` |
| `l.Close(tx)` | `w.close_loader(id) -> V` |
| `l.ChangeWorld(tx, w2)` | `v = w.close_loader(id)`, then `w2.add_loader(r, v^)` |

Chunks load synchronously on the loop (generation is bounded by the `n`
passed to `load`), so Go's pending set and asynchronous callbacks are not
needed.
"""

from std.collections import Dict, Set
from std.math import floor, sqrt

from .position import ChunkPos
from .viewer import Viewer

comptime LoaderID = UInt64
"""The world-local identifier of a loader."""


def chunk_distance(a: ChunkPos, b: ChunkPos) -> Int32:
    """Returns the rounded distance between two chunk positions (Go
    `chunkDistance`).

    Args:
        a: The first position.
        b: The second position.

    Returns:
        The Euclidean distance rounded half away from zero.
    """
    var dx = Float64(a.x()) - Float64(b.x())
    var dz = Float64(a.z()) - Float64(b.z())
    return Int32(Int(floor(sqrt(dx * dx + dz * dz) + 0.5)))


struct Loader[V: Viewer](Movable):
    """The state of one loader (Go `Loader`).

    Parameters:
        V: The viewer type.
    """

    var r: Int
    """The chunk radius."""
    var viewer: Self.V
    """The viewer chunks and changes are shown to."""
    var pos: ChunkPos
    """The chunk the loader is in."""
    var load_queue: List[ChunkPos]
    """Chunks to load, nearest first."""
    var loaded: Set[ChunkPos]
    """Chunks the viewer is viewing."""

    def __init__(out self, r: Int, var viewer: Self.V):
        """Creates a loader at chunk (0, 0) with an empty queue.

        Args:
            r: The chunk radius.
            viewer: The viewer.
        """
        self.r = r
        self.viewer = viewer^
        self.pos = ChunkPos(0, 0)
        self.load_queue = List[ChunkPos]()
        self.loaded = Set[ChunkPos]()

    def into_viewer(deinit self) -> Self.V:
        """Consumes the loader, giving its viewer back.

        Returns:
            The viewer.
        """
        return self.viewer^

    def within_load_radius(self, pos: ChunkPos) -> Bool:
        """Reports whether a chunk is within the loader's radius (Go
        `withinLoadRadius`).

        Args:
            pos: The chunk position.

        Returns:
            True if within the radius.
        """
        return chunk_distance(pos, self.pos) <= Int32(self.r)

    def queue_load(mut self, pos: ChunkPos):
        """Queues a chunk again unless it is loaded, queued or out of range
        (Go `queueLoad`).

        Args:
            pos: The chunk position.
        """
        if not self.within_load_radius(pos) or pos in self.loaded:
            return
        for q in self.load_queue:
            if q == pos:
                return
        self.load_queue.append(pos)

    def populate_load_queue(mut self):
        """Rebuilds the load queue: every chunk within the radius that is
        not loaded yet, nearest first (Go `populateLoadQueue`)."""
        var r = Int32(self.r)
        var queue = Dict[Int32, List[ChunkPos]]()
        for x in range(-r, r + 1):
            for z in range(-r, r + 1):
                var pos = ChunkPos(x + self.pos.x(), z + self.pos.z())
                var dist = chunk_distance(pos, self.pos)
                if dist > r or pos in self.loaded:
                    continue
                if dist not in queue:
                    queue[dist] = List[ChunkPos]()
                try:
                    queue[dist].append(pos)
                except:
                    pass
        self.load_queue.clear()
        for i in range(r + 1):
            if case .Some(ref l) = queue.get(i):
                self.load_queue.extend(l.copy())
