"""Light areas, ported from Dragonfly `server/world/chunk/light_area.go`.

A `LightArea` is a square of N*N chunks lit together. Go's area holds
`[]*Chunk`; here it holds `ChunkPointer`s into chunks the caller owns (the
world's loaded columns), which must stay where they are while the area is
used. Go's chunks hold the block registry; Ignis passes it to the area.

The methods Go keeps in `light.go` (node insertion and propagation) are the
free functions of `light.mojo`.

Fixed from Dragonfly: `iter_edges` also visits the top sub-chunk (Go's loop
stops one sub-chunk short of `Range.Max()`, so light never crossed a chunk
border there unless a node from below carried it).

Ignis also lets an area leave chunks out (`absent`), for relighting a block
change near chunks that are not loaded; `fill` and `spread` need them all.
"""

from ...block.cube.range import Range
from .block_registry import BlockRegistry
from .chunk import Chunk
from .light import (
    LightNode,
    insert_block_light_nodes,
    insert_light_spreading_nodes,
    insert_sky_light_nodes,
    propagate,
)
from .light_type import BLOCK_LIGHT, SKY_LIGHT
from .sub_chunk import LightArray, SubChunk, light_index

comptime ChunkPointer = Pointer[Chunk, MutUntrackedOrigin]
"""A pointer to a chunk lit by a `LightArea`."""

comptime INITIAL_LIGHT_QUEUE_CAPACITY = 1024
"""The starting size of light propagation queues (Go
`initialLightQueueCapacity`)."""


def chunk_pointer(mut c: Chunk) -> ChunkPointer:
    """Returns a pointer to a chunk for a `LightArea`."""
    return rebind[ChunkPointer](Pointer(to=c))


struct LightQueue(Movable):
    """A FIFO ring buffer of light nodes (Go `lightQueue`)."""

    var _nodes: List[LightNode]
    var _head: Int
    var _tail: Int
    var _size: Int

    def __init__(out self, capacity: Int = INITIAL_LIGHT_QUEUE_CAPACITY):
        """Creates an empty queue sized to capacity, at least 1 (Go
        `newLightQueue`)."""
        var n = max(capacity, 1)
        self._nodes = List[LightNode](length=n, fill=LightNode(0, 0, 0, 0, 0))
        self._head = 0
        self._tail = 0
        self._size = 0

    @always_inline
    def push(mut self, n: LightNode):
        """Appends a node, growing the buffer when it is full."""
        if self._size == len(self._nodes):
            self._grow()
        self._nodes.unsafe_get(self._tail) = n
        self._tail += 1
        if self._tail == len(self._nodes):
            self._tail = 0
        self._size += 1

    @always_inline
    def pop(mut self) -> LightNode:
        """Removes and returns the oldest node; the queue must not be
        empty."""
        var n = self._nodes.unsafe_get(self._head)
        self._head += 1
        if self._head == len(self._nodes):
            self._head = 0
        self._size -= 1
        return n

    def empty(self) -> Bool:
        """Reports whether no nodes are queued."""
        return self._size == 0

    def _grow(mut self):
        var n = len(self._nodes)
        var nodes = List[LightNode](capacity=n << 1)
        for i in range(self._size):
            var j = self._head + i
            if j >= n:
                j -= n
            nodes.append(self._nodes.unsafe_get(j))
        for _ in range(self._size, n << 1):
            nodes.append(LightNode(0, 0, 0, 0, 0))
        self._head = 0
        self._tail = self._size
        self._nodes = nodes^


struct LightArea[R: BlockRegistry](Movable):
    """A square area of N*N chunks used for light calculation (Go
    `lightArea`)."""

    var _br: Pointer[Self.R, ImmUntrackedOrigin]
    var base_x: Int
    """The block X of the area's lower corner."""
    var base_z: Int
    """The block Z of the area's lower corner."""
    var _c: List[ChunkPointer]
    var _present: List[Bool]
    var w: Int
    """The width of the area in chunks."""
    var r: Range
    """The vertical range of the chunks."""

    def __init__(
        out self,
        ref br: Self.R,
        var c: List[ChunkPointer],
        base_x: Int,
        base_z: Int,
    ):
        """Creates an area whose lower corner is the chunk at `base_x`,
        `base_z` (Go `LightArea`); `c` lists the chunks row by row (X first)
        and its length must be a square."""
        var w = 1
        while w * w < len(c):
            w += 1
        debug_assert(len(c) == w * w, "area must have a square chunk area")
        self._br = rebind[Pointer[Self.R, ImmUntrackedOrigin]](Pointer(to=br))
        self.r = c[0][].range()
        self._present = List[Bool](length=len(c), fill=True)
        self._c = c^
        self.w = w
        self.base_x = base_x << 4
        self.base_z = base_z << 4

    def set_absent(mut self, index: Int):
        """Marks a chunk of the area as not loaded; light does not enter it.
        Its pointer is never followed."""
        self._present[index] = False

    def fill(mut self):
        """Fills the area with the light of its own chunks, without light
        crossing chunk borders (Go `Fill`)."""
        self._initialise_light_slices()
        var queue = LightQueue()
        insert_block_light_nodes(self, queue)
        insert_sky_light_nodes(self, queue)
        while not queue.empty():
            propagate(self, queue)

    def spread(mut self):
        """Spreads light from every chunk of the area into its neighbours
        (Go `Spread`); the chunks must have been filled."""
        var queue = LightQueue()
        insert_light_spreading_nodes(self, queue, BLOCK_LIGHT)
        insert_light_spreading_nodes(self, queue, SKY_LIGHT)
        while not queue.empty():
            propagate(self, queue)

    @always_inline
    def br(self) -> ref[ImmUntrackedOrigin] Self.R:
        """Returns the block registry."""
        return self._br[]

    @always_inline
    def light(self, x: Int, y: Int, z: Int, lt: UInt8) -> UInt8:
        """Returns the light of a type at a position (Go `light`)."""
        ref sub = self.sub(x, y, z)
        var i = light_index(UInt8(x & 0xF), UInt8(y & 0xF), UInt8(z & 0xF))
        if lt == SKY_LIGHT:
            return sub._sky_light.get(i)
        return sub._block_light.get(i)

    @always_inline
    def set_light(mut self, x: Int, y: Int, z: Int, lt: UInt8, v: UInt8):
        """Sets the light of a type at a position (Go `setLight`)."""
        ref sub = self.sub(x, y, z)
        var i = light_index(UInt8(x & 0xF), UInt8(y & 0xF), UInt8(z & 0xF))
        if lt == SKY_LIGHT:
            sub._sky_light.set(i, v)
        else:
            sub._block_light.set(i, v)

    @always_inline
    def highest[emission: Bool](self, x: Int, y: Int, z: Int) -> UInt8:
        """Returns the highest light emission (or filtering, if `emission`
        is false) of the blocks on the first two layers at a position (Go
        `highest`)."""
        ref sub = self.sub(x, y, z)
        var l = len(sub._storages)
        if l == 0:
            return 0
        var ux = UInt8(x & 0xF)
        var uy = UInt8(y & 0xF)
        var uz = UInt8(z & 0xF)
        var level = self._level[emission](
            sub._storages.unsafe_get(0).at(ux, uy, uz)
        )
        if l == 1:
            return level
        return max(
            level,
            self._level[emission](sub._storages.unsafe_get(1).at(ux, uy, uz)),
        )

    @always_inline
    def _level[emission: Bool](self, rid: UInt32) -> UInt8:
        comptime if emission:
            return self._br[].light_block(rid)
        else:
            return self._br[].filtering_block(rid)

    @always_inline
    def sub(self, x: Int, y: Int, z: Int) -> ref[MutUntrackedOrigin] SubChunk:
        """Returns the sub-chunk holding a position (Go `sub`)."""
        ref c = self.chunk(x, z)
        return c._sub.unsafe_get((y - self.r.min()) >> 4)

    @always_inline
    def chunk(self, x: Int, z: Int) -> ref[MutUntrackedOrigin] Chunk:
        """Returns the chunk holding a position (Go `chunk`)."""
        return self._c.unsafe_get(
            self.chunk_index((x - self.base_x) >> 4, (z - self.base_z) >> 4)
        )[]

    @always_inline
    def chunk_index(self, x: Int, z: Int) -> Int:
        """Returns the index of the chunk at area chunk coordinates `x`,
        `z` (Go `chunkIndex`)."""
        return x + z * self.w

    @always_inline
    def contains(self, x: Int, y: Int, z: Int) -> Bool:
        """Reports whether a position is inside the area, its height range
        and a chunk that is present."""
        if y < self.r.min() or y > self.r.max():
            return False
        var cx = (x - self.base_x) >> 4
        var cz = (z - self.base_z) >> 4
        if cx < 0 or cz < 0 or cx >= self.w or cz >= self.w:
            return False
        return self._present.unsafe_get(self.chunk_index(cx, cz))

    def chunk_at(self, index: Int) -> ref[MutUntrackedOrigin] Chunk:
        """Returns the chunk at an index of the area."""
        return self._c[index][]

    def height(self, x: Int, z: Int) -> Int:
        """Returns the height map value of the column at a position."""
        ref c = self.chunk(x, z)
        return Int(c.height_at(self._br[], UInt8(x & 0xF), UInt8(z & 0xF)))

    def _initialise_light_slices(mut self):
        # Go `initialiseLightSlices`: full sky light in the empty sub-chunks
        # at the top of each chunk, no light anywhere else.
        for i in range(len(self._c)):
            ref c = self._c[i][]
            var index = len(c._sub) - 1
            while index >= 0:
                if not c._sub[index].empty():
                    break
                c._sub[index]._sky_light = LightArray(0xFF)
                c._sub[index]._block_light = LightArray(0)
                index -= 1
            while index >= 0:
                c._sub[index]._sky_light = LightArray(0)
                c._sub[index]._block_light = LightArray(0)
                index -= 1
