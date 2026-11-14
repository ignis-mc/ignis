"""World ticking, ported from Dragonfly `server/world/tick.go`.

Go ticks each world from its own goroutine every 50 ms. Here the server's
loop calls `World.tick(now_ms)`, which runs every tick that is due; the
steps of one tick (`World.advance_tick`) follow Go's `ticker.tick`.

This module holds the scheduled tick queue and the tick steps that do not
need the world's private fields.
"""

from std.collections import Dict

from ..block.cube.pos import Pos
from ..internal.rand import Rand
from .position import ChunkPos, chunk_pos_from_block_pos


@fieldwise_init
struct ScheduledTick(Copyable, Equatable, Writable):
    """A block update scheduled for a tick (Go `scheduledTick`)."""

    var pos: Pos
    """The position of the block."""
    var rid: UInt32
    """The runtime ID of the block the update was scheduled for."""
    var bhash: UInt64
    """The registry's block hash of that block (Go `BlockHash`)."""
    var t: Int64
    """The tick at which the update is due."""


@fieldwise_init
struct _TickIndex(Equatable, Hashable, ImplicitlyCopyable):
    var pos: Pos
    var hash: UInt64


struct ScheduledTickQueue(Copyable):
    """Scheduled block updates, unique per position and block (Go
    `scheduledTickQueue`)."""

    var ticks: List[ScheduledTick]
    """The pending updates, in scheduling order."""
    var _furthest: Dict[_TickIndex, Int64]
    var current_tick: Int64
    """The tick the queue last processed."""

    def __init__(out self, tick: Int64):
        """Creates an empty queue (Go `newScheduledTickQueue`)."""
        self.ticks = List[ScheduledTick]()
        self._furthest = Dict[_TickIndex, Int64]()
        self.current_tick = tick

    def schedule(mut self, pos: Pos, rid: UInt32, bhash: UInt64, delay_ms: Int):
        """Schedules an update unless one for the same position and block is
        already scheduled at or after the resulting tick (Go `schedule`)."""
        var res_tick = self.current_tick + Int64(max(delay_ms // 50, 1))
        var index = _TickIndex(pos, bhash)
        if case .Some(t) = self._furthest.get(index):
            if t >= res_tick and t > self.current_tick:
                return
        self._furthest[index] = res_tick
        self.ticks.append(ScheduledTick(pos, rid, bhash, res_tick))

    def take_due(mut self, tick: Int64) -> List[ScheduledTick]:
        """Removes and returns the updates due at `tick` (the first half of
        Go's `tick`; the world runs them)."""
        self.current_tick = tick
        var due = List[ScheduledTick]()
        var kept = List[ScheduledTick]()
        for t in self.ticks:
            if t.t <= tick:
                due.append(t.copy())
            else:
                kept.append(t.copy())
        self.ticks = kept^
        var stale = List[_TickIndex]()
        for e in self._furthest.items():
            if e.value <= tick:
                stale.append(e.key)
        for k in stale:
            _ = self._furthest.pop(k, 0)
        return due^

    def from_chunk(self, pos: ChunkPos) -> List[ScheduledTick]:
        """Returns the updates in a chunk (Go `fromChunk`)."""
        var out = List[ScheduledTick]()
        for t in self.ticks:
            if chunk_pos_from_block_pos(t.pos) == pos:
                out.append(t.copy())
        return out^

    def remove_chunk(mut self, pos: ChunkPos):
        """Removes the updates in a chunk (Go `removeChunk`)."""
        var kept = List[ScheduledTick]()
        for t in self.ticks:
            if chunk_pos_from_block_pos(t.pos) != pos:
                kept.append(t.copy())
        self.ticks = kept^
        var stale = List[_TickIndex]()
        for e in self._furthest.items():
            if chunk_pos_from_block_pos(e.key.pos) == pos:
                stale.append(e.key)
        for k in stale:
            _ = self._furthest.pop(k, 0)

    def add(mut self, ticks: List[ScheduledTick]):
        """Adds updates read from a provider (Go `add`)."""
        for t in ticks:
            self.ticks.append(t.copy())
            var index = _TickIndex(t.pos, t.bhash)
            if case .Some(existing) = self._furthest.get(index):
                self._furthest[index] = max(existing, t.t)
            else:
                self._furthest[index] = t.t


@fieldwise_init
struct NeighbourUpdate(Copyable, ImplicitlyCopyable):
    """A position to update because a neighbour changed (Go
    `neighbourUpdate`)."""

    var pos: Pos
    """The position to update."""
    var neighbour: Pos
    """The position that changed."""


struct RandUint4(Copyable, Defaultable):
    """Draws random 4-bit values, 16 per 64-bit draw (Go `randUint4`)."""

    var _x: UInt64
    var _n: UInt8

    def __init__(out self):
        """Creates a drawer with no bits buffered."""
        self._x = 0
        self._n = 0

    def uint4(mut self, mut r: Rand) -> UInt8:
        """Returns a random value in [0, 16) (Go `uint4`)."""
        if self._n == 0:
            self._x = r.uint64()
            self._n = 16
        var v = UInt8(self._x & 0xF)
        self._x >>= 4
        self._n -= 1
        return v


def any_within_distance(
    pos: ChunkPos, loaded: List[ChunkPos], r: Int32
) -> Bool:
    """Reports whether any of the positions is within `r` chunks of `pos`
    (Go `anyWithinDistance`)."""
    for c in loaded:
        var dx = c.x() - pos.x()
        var dz = c.z() - pos.z()
        if dx * dx + dz * dz <= r * r:
            return True
    return False
