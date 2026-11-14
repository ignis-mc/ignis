"""Passive and stationary entities, ported from Dragonfly
`server/entity/passive.go` and `stationary.go`.

Go's behaviours take `Tick` and `Expire` closures; here the entity types
call `step` (movement), run their own tick code, then `expired`, and run
their expiry code when it reports True. Durations are milliseconds.
Viewers are not sent the entity state every quarter second yet (Go
`ViewEntityState`).
"""

from minecraft.protocol.uuid import UUID

from ..block.cube.bbox import BBox
from ..world.entity import EntityData, EntityMovement
from ..world.world import World, WorldTypes
from .movement import MovementComputer

comptime FOREVER_MS = Int.MAX
"""An existence duration that never runs out (Go `math.MaxInt64`)."""


struct PassiveBehaviour(Copyable, Defaultable):
    """An entity that only moves (Go `PassiveBehaviour`)."""

    var mc: MovementComputer
    """Gravity, drag (applied before gravity) and collisions."""
    var existence_ms: Int
    """How long it exists (Go `ExistenceDuration`)."""
    var close: Bool
    """Set to remove it on the next tick (Go `close`)."""
    var fall_distance: Float64
    """How far it has fallen (Go `fallDistance`)."""
    var fuse_ms: Int
    """The time left of its existence (Go `fuse`)."""

    def __init__(out self):
        """Creates a behaviour without forces that exists forever."""
        self = Self(0, 0, 0)

    def __init__(out self, gravity: Float64, drag: Float64, existence_ms: Int):
        """Creates a behaviour (Go `PassiveBehaviourConfig.New`); an
        existence of 0 is forever."""
        self.mc = MovementComputer(gravity, drag)
        self.mc.drag_before_gravity = True
        self.existence_ms = existence_ms if existence_ms != 0 else FOREVER_MS
        self.close = False
        self.fall_distance = 0
        self.fuse_ms = self.existence_ms

    def step[
        T: WorldTypes
    ](mut self, mut data: EntityData, mut tx: World[T], bbox: BBox) -> Optional[
        EntityMovement
    ]:
        """Moves the entity (Go `Tick` up to its `Tick` closure); None if it
        closed itself and should be removed."""
        if self.close:
            return None
        var old_y = data.pos.y()
        var m = self.mc.tick_movement(bbox, data.pos, data.vel, data.rot, tx)
        data.pos = m.pos
        data.vel = m.vel
        self.fall_distance = max(self.fall_distance - (m.pos.y() - old_y), 0)
        if self.existence_ms == FOREVER_MS:
            self.fuse_ms = FOREVER_MS
        else:
            self.fuse_ms = self.existence_ms - data.age_ms
        return m

    def expired(mut self, data: EntityData) -> Bool:
        """Closes the entity once it outlived its existence and reports
        whether that happened now (Go's `Expire` call)."""
        if self.existence_ms != FOREVER_MS and data.age_ms > self.existence_ms:
            self.close = True
            return True
        return False


struct StationaryBehaviour(Copyable, Defaultable):
    """An entity that does not move (Go `StationaryBehaviour`)."""

    var existence_ms: Int
    """How long it exists (Go `ExistenceDuration`)."""
    var close: Bool
    """Set to remove it on the next tick (Go `close`)."""

    def __init__(out self):
        """Creates a behaviour that exists forever."""
        self = Self(0)

    def __init__(out self, existence_ms: Int):
        """Creates a behaviour (Go `StationaryBehaviourConfig.New`); an
        existence of 0 is forever."""
        self.existence_ms = existence_ms if existence_ms != 0 else FOREVER_MS
        self.close = False

    def closed(self) -> Bool:
        """Reports whether the entity should be removed now (Go's first
        check in `Tick`)."""
        return self.close

    def spawned(self, data: EntityData) -> Bool:
        """Reports whether this is the entity's first tick, when Go plays
        its spawn sounds."""
        return data.age_ms == 0

    def expire(mut self, data: EntityData):
        """Closes the entity once it outlived its existence (the end of Go
        `Tick`)."""
        if self.existence_ms != FOREVER_MS and data.age_ms > self.existence_ms:
            self.close = True
