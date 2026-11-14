"""Entity movement with gravity, drag and block collisions, ported from
Dragonfly `server/entity/movement.go` (`MovementComputer`).

Go's `Movement` keeps the viewers and sends itself; here `tick_movement`
returns the world's `EntityMovement`, which the world shows to viewers.
Block friction (Go's `Friction` interface) is not ported: every block
below a grounded entity has Go's default 0.6.
"""

from std.math import ceil, floor

from ..block.cube.bbox import BBox
from ..block.cube.pos import Pos
from ..block.cube.rotation import Rotation
from ..mgl64 import Vec3, float_equal, float_equal_threshold
from ..world.entity import EntityMovement
from ..world.world import World, WorldTypes

comptime _EPSILON = 0.001
"""Go `epsilon`."""


struct MovementComputer(Copyable, Defaultable):
    """Moves an entity each tick (Go `MovementComputer`)."""

    var gravity: Float64
    """Blocks per tick squared subtracted from the vertical velocity."""
    var drag: Float64
    """The fraction of velocity lost per tick."""
    var drag_before_gravity: Bool
    """Apply drag before gravity (Go `DragBeforeGravity`)."""
    var on_ground: Bool
    """Whether the entity stood on a block after the last tick."""

    def __init__(out self):
        """Creates a computer without forces."""
        self = Self(0, 0)

    def __init__(out self, gravity: Float64, drag: Float64):
        """Creates a computer with gravity and drag applied after it."""
        self.gravity = gravity
        self.drag = drag
        self.drag_before_gravity = False
        self.on_ground = False

    def tick_movement[
        T: WorldTypes
    ](
        mut self,
        bbox: BBox,
        pos: Vec3,
        vel: Vec3,
        rot: Rotation,
        mut tx: World[T],
    ) -> EntityMovement:
        """Applies forces and collisions for one tick (Go `TickMovement`);
        `bbox` is the entity's box relative to its position."""
        var v = self._horizontal(self._vertical(vel))
        var r = self.check_collision(tx, bbox, pos, v)
        var dpos = r[0]
        var new_vel = r[1]
        var dvel = new_vel.sub(vel)
        return EntityMovement(
            pos=pos.add(dpos),
            rot=rot,
            vel=new_vel,
            on_ground=self.on_ground,
            moved=not _near_zero(dpos),
            vel_changed=not _near_zero(dvel),
        )

    def _vertical(self, vel: Vec3) -> Vec3:
        # Go applyVerticalForces.
        var y = vel.y()
        if self.drag_before_gravity:
            y *= 1 - self.drag
        y -= self.gravity
        if not self.drag_before_gravity:
            y *= 1 - self.drag
        return Vec3(vel.x(), y, vel.z())

    def _horizontal(self, vel: Vec3) -> Vec3:
        # Go applyHorizontalForces, with the default block friction.
        var friction = 1 - self.drag
        if self.on_ground:
            friction *= 0.6
        return Vec3(vel.x() * friction, vel.y(), vel.z() * friction)

    def check_collision[
        T: WorldTypes
    ](mut self, mut tx: World[T], bbox: BBox, pos: Vec3, vel: Vec3) -> Tuple[
        Vec3, Vec3
    ]:
        """Clips a movement against the blocks around the entity (Go
        `CheckCollision`) and returns the movement and the new velocity."""
        var dx = vel.x()
        var dy = vel.y()
        var dz = vel.z()
        var box = bbox.translate(pos)
        var blocks = block_bboxes_around(tx, box.extend(vel))
        if not float_equal_threshold(dy, 0, _EPSILON):
            for b in blocks:
                dy = box.y_offset(b, dy)
            box = box.translate(Vec3(0, dy, 0))
        if not float_equal_threshold(dx, 0, _EPSILON):
            for b in blocks:
                dx = box.x_offset(b, dx)
            box = box.translate(Vec3(dx, 0, 0))
        if not float_equal_threshold(dz, 0, _EPSILON):
            for b in blocks:
                dz = box.z_offset(b, dz)
        var vx = vel.x()
        var vy = vel.y()
        var vz = vel.z()
        if not float_equal(vy, 0):
            self.on_ground = False
        if not float_equal(dx, vx):
            vx = 0
        if not float_equal(dy, vy):
            if vy < 0:
                self.on_ground = True
            vy = 0
        if not float_equal(dz, vz):
            vz = 0
        return (Vec3(dx, dy, dz), Vec3(vx, vy, vz))


def block_bboxes_around[
    T: WorldTypes
](mut tx: World[T], box: BBox) -> List[BBox]:
    """Returns the boxes of the blocks around a box, translated to their
    positions (Go `blockBBoxsAround`)."""
    var grown = box.grow(0.25)
    var lo = grown.min()
    var hi = grown.max()
    var min_x = Int(floor(lo.x()))
    var min_y = Int(floor(lo.y()))
    var min_z = Int(floor(lo.z()))
    var max_x = Int(ceil(hi.x()))
    var max_y = Int(ceil(hi.y()))
    var max_z = Int(ceil(hi.z()))
    var out = List[BBox]()
    var br = tx.block_registry()
    for y in range(min_y, max_y):
        for x in range(min_x, max_x):
            for z in range(min_z, max_z):
                var pos = Pos(x, y, z)
                var rid = tx.block(pos)
                var boxes = T.Blocks.model_bbox(
                    br[].kind(rid), br[].state_hash(rid), pos, tx.source()
                )
                for b in boxes:
                    out.append(
                        b.translate(Vec3(Float64(x), Float64(y), Float64(z)))
                    )
    return out^


def _near_zero(v: Vec3) -> Bool:
    # Go `ApproxEqualThreshold(zeroVec3, epsilon)`.
    return (
        float_equal_threshold(v.x(), 0, _EPSILON)
        and float_equal_threshold(v.y(), 0, _EPSILON)
        and float_equal_threshold(v.z(), 0, _EPSILON)
    )
