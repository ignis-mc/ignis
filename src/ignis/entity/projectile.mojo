"""Projectiles, ported from Dragonfly `server/entity/projectile.go`.

Go's `ProjectileBehaviour.Tick` does everything and calls the `Hit` closure
of its config; here the projectile types drive it in steps, so that each
type plays its own particle and sound and runs its own hit code:
`step` moves the projectile and returns what it hit, `hit_target` applies
Go's entity and block handling, and `finish` closes a projectile that hit
more entities than it may pierce.

Not ported yet: hurting, knocking back and applying potion effects to living
entities (no living entities are in the world yet; the filter only lets
`DamageableEntity`s be hit), picking up stuck arrows (collectors are
players), and portal travel.
"""

from std.math import atan2, hypot, pi, sqrt

from minecraft.protocol.uuid import UUID

from ..block.cube.bbox import BBox
from ..block.cube.pos import Pos
from ..block.cube.rotation import Rotation
from ..block.cube.trace.perform import EntityFilter, TraceResult, perform
from ..item.potion.potion import Potion
from ..item.stack import Stack
from ..mgl64 import Vec3, float_equal, float_equal_threshold
from ..world.entity import EntityData, EntityMovement
from ..world.world import World, WorldTypes
from .movement import MovementComputer

comptime _EPSILON = 0.001


@fieldwise_init
struct ProjectileStep(Copyable):
    """What one tick of a projectile's movement did."""

    var movement: Optional[EntityMovement]
    """The movement to show, if it moved."""
    var hit: Optional[TraceResult]
    """What it hit, if anything."""
    var vel_before: Vec3
    """Its velocity before the tick (Go `vel` in `Tick`)."""


struct ProjectileBehaviour(Copyable, Defaultable):
    """The movement and collisions of a projectile (Go
    `ProjectileBehaviour` with its `ProjectileBehaviourConfig`)."""

    var owner: UUID
    """The entity that shot it (Go `Owner`); zero for none."""
    var gravity: Float64
    """Go `Gravity`."""
    var drag: Float64
    """Go `Drag`."""
    var damage: Float64
    """Damage per block per tick of speed; negative for none (Go
    `Damage`)."""
    var potion: Potion
    """The potion it applies (Go `Potion`)."""
    var knock_back_force_addend: Float64
    """Go `KnockBackForceAddend`."""
    var knock_back_height_addend: Float64
    """Go `KnockBackHeightAddend`."""
    var critical: Bool
    """Go `Critical`."""
    var survive_block_collision: Bool
    """It stays stuck in blocks instead of closing (Go
    `SurviveBlockCollision`)."""
    var block_collision_velocity_multiplier: Float64
    """Go `BlockCollisionVelocityMultiplier`."""
    var disable_pickup: Bool
    """Go `DisablePickup`."""
    var pickup_item: Stack
    """What picking it up gives (Go `PickupItem`)."""
    var piercing_level: Int
    """How many entities it passes through (Go `PiercingLevel`)."""
    var mc: MovementComputer
    """Gravity and drag (Go `mc`, drag before gravity)."""
    var age_collided: Int
    """Ticks spent stuck in a block (Go `ageCollided`)."""
    var close: Bool
    """Set to remove it on the next tick (Go `close`)."""
    var collision_pos: Pos
    """The block it is stuck in (Go `collisionPos`)."""
    var collided: Bool
    """Whether it is stuck in a block (Go `collided`)."""
    var collided_entities: List[UUID]
    """The entities it hit (Go `collidedEntities`)."""

    def __init__(out self):
        """Creates a behaviour without forces."""
        self = Self(0, 0)

    def __init__(
        out self,
        gravity: Float64,
        drag: Float64,
        *,
        damage: Float64 = 0,
        survive_block_collision: Bool = False,
        collision_pos: Pos = Pos(0, 0, 0),
    ):
        """Creates a behaviour (Go `ProjectileBehaviourConfig.New`); a
        non-zero `collision_pos` starts it stuck in that block."""
        self.owner = UUID()
        self.gravity = gravity
        self.drag = drag
        self.damage = damage
        self.potion = Potion.WATER
        self.knock_back_force_addend = 0
        self.knock_back_height_addend = 0
        self.critical = False
        self.survive_block_collision = survive_block_collision
        self.block_collision_velocity_multiplier = 0
        self.disable_pickup = False
        self.pickup_item = Stack()
        self.piercing_level = 0
        self.mc = MovementComputer(gravity, drag)
        self.mc.drag_before_gravity = True
        self.age_collided = 0
        self.close = False
        self.collision_pos = collision_pos
        self.collided = collision_pos != Pos(0, 0, 0)
        self.collided_entities = List[UUID]()

    def is_critical(self) -> Bool:
        """Reports whether it shows critical particles (Go `Critical`)."""
        return self.critical and not self.collided

    def step[
        T: WorldTypes
    ](
        mut self, id: UUID, mut data: EntityData, mut tx: World[T], bbox: BBox
    ) -> Optional[ProjectileStep]:
        """Moves the projectile for a tick (the first part of Go `Tick`);
        None if it closed itself and should be removed."""
        if self.close:
            return None
        if self.collided and self._tick_attached(data, tx, bbox):
            if self.age_collided > 1200:
                self.close = True
            return ProjectileStep(None, None, data.vel)
        var vel = data.vel
        var r = self._tick_movement(id, data, tx, bbox)
        var m = r[0]
        data.pos = m.pos
        data.vel = m.vel
        data.rot = m.rot
        self.collision_pos = Pos(0, 0, 0)
        self.collided = False
        self.age_collided = 0
        return ProjectileStep(m, r[1], vel)

    def hit_target[
        T: WorldTypes
    ](
        mut self,
        mut data: EntityData,
        mut tx: World[T],
        step: ProjectileStep,
    ) -> Bool:
        """Applies Go's handling of what the projectile hit; returns whether
        the type's `Hit` code runs (not for a block it stays stuck in)."""
        ref hit = step.hit.value()
        if case .Some(e) = hit.entity:
            # TODO(player): hurt, knock back and apply effects (Go
            # `hitEntity`); every entity it can hit is damageable.
            self.collided_entities.append(e.entity())
            return True
        ref b = hit.block.value()
        # TODO: Go's `ProjectileHitter` blocks (TNT lit by a burning arrow,
        # decorated pots) come with them.
        if self.survive_block_collision:
            self._hit_block_surviving(data, b.block_position())
            return False
        self.close = True
        return True

    def finish(mut self):
        """Closes a projectile that hit more entities than it pierces (the
        end of Go `Tick`)."""
        if len(self.collided_entities) > self.piercing_level:
            self.close = True

    def _tick_attached[
        T: WorldTypes
    ](mut self, data: EntityData, mut tx: World[T], bbox: BBox) -> Bool:
        # Go `tickAttached`.
        var br = tx.block_registry()
        var rid = tx.block(self.collision_pos)
        var boxes = T.Blocks.model_bbox(
            br[].kind(rid),
            br[].state_hash(rid),
            self.collision_pos,
            tx.source(),
        )
        var box = bbox.translate(data.pos)
        for bb in boxes:
            if box.intersects_with(
                bb.translate(self.collision_pos.vec3()).grow(0.05)
            ):
                # TODO(player): Go `tryPickup` once ageCollided > 5; the
                # collectors are players.
                self.age_collided += 1
                return True
        return False

    def _hit_block_surviving(mut self, mut data: EntityData, pos: Pos):
        # Go `hitBlockSurviving`; the viewers' teleport, arrow shake and
        # state come with entity actions.
        var eps = sqrt(0.1 * (1 - self.block_collision_velocity_multiplier))
        if float_equal_threshold(data.vel.len(), 0, eps):
            data.vel = Vec3()
            self.collision_pos = pos
            self.collided = True

    def _tick_movement[
        T: WorldTypes
    ](
        mut self, id: UUID, data: EntityData, mut tx: World[T], bbox: BBox
    ) -> Tuple[EntityMovement, Optional[TraceResult]]:
        # Go `tickMovement`.
        var pos = data.pos
        var vel = self.mc._horizontal(self.mc._vertical(data.vel))
        var vel_before = data.vel
        var rot = Rotation(
            atan2(vel.x(), vel.z()) * 180 / pi,
            atan2(vel.y(), hypot(vel.x(), vel.z())) * 180 / pi,
        )
        var end = pos.add(vel)
        var hit: Optional[TraceResult] = None
        if not float_equal(end.sub(pos).len_sqr(), 0):
            var filter = _ProjectileFilter(
                self.owner, data.age_ms, self.collided_entities.copy()
            )
            hit = perform(pos, end, tx, bbox.grow(1.0), filter)
            if case .Some(h) = hit:
                if h.block:
                    var vy = (vel.y() + self.gravity) / (1 - self.drag)
                    var v = Vec3(vel.x(), vy, vel.z()).mul(
                        self.block_collision_velocity_multiplier
                    )
                    var m = h.face().axis().vec3().mul(-2).add(Vec3(1, 1, 1))
                    vel = Vec3(v.x() * m.x(), v.y() * m.y(), v.z() * m.z())
                elif self.piercing_level == 0:
                    vel = Vec3()
                end = h.position()
        var dpos = end.sub(pos)
        return (
            EntityMovement(
                pos=end,
                rot=rot,
                vel=vel,
                on_ground=False,
                moved=not _near_zero(dpos),
                vel_changed=not _near_zero(vel.sub(vel_before)),
            ),
            hit,
        )


struct _ProjectileFilter(EntityFilter, Movable):
    # Go `ProjectileBehaviour.ignores`. The projectile itself is out of the
    # world while it ticks; there are no spectators among world entities.
    var owner: UUID
    var age_ms: Int
    var collided: List[UUID]

    def __init__(out self, owner: UUID, age_ms: Int, var collided: List[UUID]):
        self.owner = owner
        self.age_ms = age_ms
        self.collided = collided^

    def keep[T: WorldTypes](self, id: UUID, mut tx: World[T]) -> Bool:
        var e = tx.entity(id)
        if not e:
            return False
        if not T.Entities.damageable(e.value().state):
            return False
        if self.age_ms < 250 and id == self.owner:
            return False
        for c in self.collided:
            if c == id:
                return False
        return True


def _near_zero(v: Vec3) -> Bool:
    # Go `ApproxEqualThreshold(zeroVec3, epsilon)`.
    return (
        float_equal_threshold(v.x(), 0, _EPSILON)
        and float_equal_threshold(v.y(), 0, _EPSILON)
        and float_equal_threshold(v.z(), 0, _EPSILON)
    )
