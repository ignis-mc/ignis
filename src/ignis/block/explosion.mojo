"""Explosions, ported from Dragonfly `server/block/explosion.go` (with
`ExplosionSource` from `server/world/explosion.go`).

Go's `ExplosionSource` interface is a position and a size here. Go seeds a
generator from the clock when `RandSource` is not set; `ExplosionConfig`
takes a seeded `Rand`, and the world's callers seed it from the world's
stand-in for Go's global source. Break handlers of blocks are not ported.
"""

from std.collections import Dict
from std.math import ceil, floor

from minecraft.protocol.uuid import UUID

from ..entity.living_request import REQUEST_EXPLODE, LivingRequest
from ..entity.tnt import spawn_tnt
from ..internal.rand import Rand
from ..mgl64 import Vec3
from ..world.particle.entity import HugeExplosion
from ..world.sound.entity import Explosion as ExplosionSound
from ..world.tx import Context
from ..world.world import World, WorldTypes
from .air import Air
from .break_info import drop_item, tool_none_drops
from .cube.bbox import BBox
from .cube.face import Face
from .cube.pos import Pos, pos_from_vec3
from .cube.trace.perform import trace_block
from .cube.trace.trace import traverse_blocks
from .fire import start_fire
from .block import face_solid_at
from .tnt import TNT

comptime DEFAULT_EXPLOSION_SIZE = 4.0
"""Go `defaultExplosionSize`."""

comptime _RESISTS: UInt8 = 1
comptime _STOPS_RAY: UInt8 = 2
comptime _AFFECTED: UInt8 = 4


@fieldwise_init
struct ExplosionSource(ImplicitlyCopyable):
    """Where an explosion happens and how big it is (Go
    `world.ExplosionSource`)."""

    var position: Vec3
    """Go `Position`."""
    var size: Float64
    """Go `Size`; 0 means the default of 4."""

    def explosion_size(self) -> Float64:
        """Returns the size, 4 if none was set."""
        return self.size if self.size != 0 else DEFAULT_EXPLOSION_SIZE


struct ExplosionConfig(Movable):
    """How an explosion behaves (Go `ExplosionConfig`); the sound and
    particle are Go's defaults."""

    var rand: Rand
    """The generator for ray strength, drops and fire (Go `RandSource`)."""
    var spawn_fire: Bool
    """Go `SpawnFire`."""
    var suppress_underwater_impact: Bool
    """Go `SuppressUnderwaterImpact`."""
    var item_drop_chance: Float64
    """The chance a broken block drops; 0 means 1/size (Go
    `ItemDropChance`)."""

    def __init__(out self, var rand: Rand):
        """Creates a configuration with Go's zero values."""
        self.rand = rand^
        self.spawn_fire = False
        self.suppress_underwater_impact = False
        self.item_drop_chance = 0


@fieldwise_init
struct _BlockInfo(ImplicitlyCopyable):
    var resistance: Float64
    var flags: UInt8


def explosion_rays() -> List[Vec3]:
    """Returns the 1352 ray steps of an explosion (Go `rays`)."""
    var out = List[Vec3](capacity=1352)
    for xi in range(16):
        for yi in range(16):
            for zi in range(16):
                var x = Float64(xi)
                var y = Float64(yi)
                var z = Float64(zi)
                if (
                    x != 0
                    and x != 15
                    and y != 0
                    and y != 15
                    and z != 0
                    and z != 15
                ):
                    continue
                out.append(
                    Vec3(x / 15 * 2 - 1, y / 15 * 2 - 1, z / 15 * 2 - 1)
                    .normalize()
                    .mul(0.3)
                )
    return out^


def explode[
    T: WorldTypes
](mut tx: World[T], src: ExplosionSource, mut c: ExplosionConfig):
    """Explodes: pushes or destroys entities in range, breaks the blocks the
    rays reach with their drops, and may start fires (Go `Explode`)."""
    var size = src.explosion_size()
    var explosion_pos = src.position
    if c.item_drop_chance == 0:
        c.item_drop_chance = 1.0 / size
    var d = size * 2
    var box = BBox.box(
        floor(explosion_pos.x() - d - 1),
        floor(explosion_pos.y() - d - 1),
        floor(explosion_pos.z() - d - 1),
        ceil(explosion_pos.x() + d + 1),
        ceil(explosion_pos.y() + d + 1),
        ceil(explosion_pos.z() + d + 1),
    )
    var affected_entities = List[UUID]()
    for id in tx.entities_within(box.grow(2)):
        var e = tx.entity(id)
        if not e:
            continue
        var dist = e.value().data.pos.sub(explosion_pos).len()
        if dist > d or dist == 0:
            continue
        affected_entities.append(id)

    var br = tx.block_registry()
    var air = br[].air_runtime_id()
    var affected_blocks = List[Pos]()
    var cache = Dict[Pos, _BlockInfo]()
    for ray in explosion_rays():
        var pos = explosion_pos
        var blast_force = size * (0.7 + c.rand.float64() * 0.6)
        while blast_force > 0.0:
            var current = pos_from_vec3(pos)
            var info: _BlockInfo
            if case .Some(found) = cache.get(current):
                info = found
            else:
                info = _BlockInfo(0, 0)
                var rid = tx.block(current)
                if tx.liquid(current):
                    # Water and lava both have a blast resistance of 100.
                    info.resistance = 100
                    info.flags = _RESISTS
                elif case .Some(bi) = T.Blocks.break_info(
                    br[].kind(rid), br[].state_hash(rid)
                ):
                    info.resistance = bi.blast_resistance
                    info.flags = _RESISTS
                elif rid != air:
                    info.flags = _STOPS_RAY
                cache[current] = info
            if info.flags & _STOPS_RAY != 0:
                break
            pos = pos.add(ray)
            if info.flags & _RESISTS != 0:
                blast_force -= (info.resistance + 0.3) * 0.3
            if blast_force > 0 and info.flags & _AFFECTED == 0:
                info.flags |= _AFFECTED
                cache[current] = info
                affected_blocks.append(current)
            blast_force -= 0.225

    var ctx = Context()
    var spawn_fire = c.spawn_fire
    var item_drop_chance = c.item_drop_chance
    tx.handle_explosion(
        ctx,
        explosion_pos,
        size,
        affected_entities,
        affected_blocks,
        item_drop_chance,
        spawn_fire,
    )
    if ctx.cancelled():
        return

    for id in affected_entities:
        var e = tx.entity(id)
        if not e:
            continue
        ref h = e.value()
        var impact = (1 - h.data.pos.sub(explosion_pos).len() / d) * _exposure(
            tx, explosion_pos, h.bbox().translate(h.data.pos), c
        )
        if c.suppress_underwater_impact and impact <= 0:
            continue
        if T.Entities.living(h.state):
            # Go `Player.Explode`, which needs the size: see `LivingRequest`.
            var r = LivingRequest(REQUEST_EXPLODE)
            r.pos = explosion_pos
            r.size = size
            r.impact = impact
            _ = tx.living_request(id, r^)
            continue
        tx.explode_entity(id, explosion_pos, impact)

    var blast = Dict[Pos, Bool]()
    for pos in affected_blocks:
        blast[pos] = True
    for pos in affected_blocks:
        var rid = tx.block(pos)
        var kind = br[].kind(rid)
        var hash = br[].state_hash(rid)
        if br[].is_block[TNT](rid):
            # Go `TNT.Explode`: lit with a short fuse drawn from Go's global
            # source.
            spawn_tnt(tx, pos, 500 + tx.global_rand().int_n(1500))
        elif T.Blocks.break_info(kind, hash):
            tx.set_block_runtime_id(pos, air)
            if item_drop_chance > c.rand.float64():
                for ref drop in tool_none_drops(rid, tx):
                    drop_item(tx, drop, pos.vec3_centre())
            _remove_dependents(pos, tx, blast)

    if spawn_fire:
        for pos in affected_blocks:
            if c.rand.int_n(3) == 0:
                # Go asks the block below about its face at `pos`.
                if tx.block(pos) == air and face_solid_at(
                    tx, pos.side(Face.DOWN), Face.UP
                ):
                    start_fire(tx, pos)

    tx.add_particle(explosion_pos, HugeExplosion())
    tx.play_sound(explosion_pos, ExplosionSound())


def _exposure[
    T: WorldTypes
](mut tx: World[T], origin: Vec3, box: BBox, c: ExplosionConfig) -> Float64:
    # Go `exposure`: the share of points of the box the explosion sees.
    var box_min = box.min()
    var box_max = box.max()
    var diff = box_max.sub(box_min).mul(2.0).add(Vec3(1, 1, 1))
    var step = Vec3(1.0 / diff.x(), 1.0 / diff.y(), 1.0 / diff.z())
    if step.x() < 0.0 or step.y() < 0.0 or step.z() < 0.0:
        return 0.0
    var x_offset = (1.0 - floor(diff.x()) / diff.x()) / 2.0
    var z_offset = (1.0 - floor(diff.z()) / diff.z()) / 2.0
    var checks = 0.0
    var misses = 0.0
    var x = 0.0
    while x <= 1.0:
        var y = 0.0
        while y <= 1.0:
            var z = 0.0
            while z <= 1.0:
                var point = Vec3(
                    _lerp(x, box_min.x(), box_max.x()) + x_offset,
                    _lerp(y, box_min.y(), box_max.y()),
                    _lerp(z, box_min.z(), box_max.z()) + z_offset,
                )
                if not _collides(
                    tx, origin, point, c.suppress_underwater_impact
                ):
                    misses += 1
                checks += 1
                z += step.z()
            y += step.y()
        x += step.x()
    return misses / checks


def _collides[
    T: WorldTypes
](mut tx: World[T], origin: Vec3, point: Vec3, underwater: Bool) -> Bool:
    # The `TraverseBlocks` callback of Go `exposure`.
    var positions = List[Pos]()

    def collect(p: Pos) {mut positions} -> Bool:
        positions.append(p)
        return True

    traverse_blocks(origin, point, collect)
    for p in positions:
        if underwater and tx.liquid(p):
            return True
        if trace_block(tx, p, origin, point):
            return True
    return False


def _lerp(a: Float64, b: Float64, t: Float64) -> Float64:
    # Go `lerp`, argument order and all.
    return b + a * (t - b)


def _remove_dependents[
    T: WorldTypes
](pos: Pos, mut tx: World[T], blast: Dict[Pos, Bool]):
    # Go `removeDependents`: updates the blasted neighbours of a broken block.
    var br = tx.block_registry()
    for neighbour in pos.neighbours(tx.range()):
        if neighbour not in blast:
            continue
        var rid = tx.block(neighbour)
        _ = T.Blocks.neighbour_update_tick(
            br[].kind(rid), br[].state_hash(rid), neighbour, pos, tx
        )
