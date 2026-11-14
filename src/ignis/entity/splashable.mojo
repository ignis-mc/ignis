"""Splashing potions, ported from Dragonfly `server/entity/splashable.go`.

The potion's effects reach the living entities within 4 blocks (players,
through their `PlayerProxy`), weaker further away. Splashing water puts out
fire and campfires, and lingering potions leave an area effect cloud, as in
Go.
"""

from ..block.campfire import Campfire
from ..block.cube.bbox import BBox
from ..block.cube.face import Face
from ..block.cube.pos import Pos
from ..block.cube.trace.perform import TraceResult
from ..block.fire import Fire
from ..item.potion.potion import Potion
from ..mgl64 import Vec3
from ..world.entity import EntityData, EntityHandle, EntitySpawnOpts
from ..world.sound.block import FireExtinguish
from ..world.world import World, WorldTypes
from .area_effect_cloud import AreaEffectCloud
from .effect import SECOND
from .living_request import REQUEST_EFFECT, LivingRequest


def potion_splash[
    T: WorldTypes
](
    mut tx: World[T],
    data: EntityData,
    box: BBox,
    res: TraceResult,
    dur_mul: Float64,
    pot: Potion,
    linger: Bool,
):
    """Splashes a potion where it landed (Go `potionSplash`)."""
    var pos = data.pos
    var effects = pot.effects()
    if len(effects) > 0:
        var at = box.translate(pos)
        var near = at.grow_vec3(Vec3(4.125, 2.125, 4.125))
        for other in tx.entities_within(at.grow_vec3(Vec3(8.25, 4.25, 8.25))):
            var e = tx.entity(other)
            if not e or not T.Entities.living(e.value().state):
                continue
            var opos = e.value().data.pos
            if not e.value().bbox().translate(opos).intersects_with(near):
                continue
            var dist = opos.sub(pos).len()
            if dist > 4:
                continue
            var f = 1 - dist / 4
            if case .Some(er) = res.entity:
                if er.entity() == other:
                    f = 1
            var r = LivingRequest(REQUEST_EFFECT)
            for eff in effects:
                if not eff.lasting():
                    r.effects.append(eff.with_potency(f))
                    continue
                var dur = Int(Float64(eff.duration()) * dur_mul * f)
                if dur < SECOND:
                    continue
                r.effects.append(eff.renewed(dur))
            _ = tx.living_request(other, r^)
    elif pot == Potion.WATER:
        if case .Some(result) = res.block:
            var block_pos = result.block_position().side(result.face())
            _put_out_fire(tx, block_pos)
            for f in [Face.NORTH, Face.EAST, Face.SOUTH, Face.WEST]:
                var h = block_pos.side(f)
                _put_out_fire(tx, h)
                _splash_block(tx, h)
            _splash_block(tx, result.block_position())
    if linger:
        var state = T.Entities.try_wrap(AreaEffectCloud(pot))
        if state:
            var opts = EntitySpawnOpts()
            opts.position = pos
            _ = tx.add_entity(EntityHandle[T.Entities](opts, state.take()))


def _put_out_fire[T: WorldTypes](mut tx: World[T], pos: Pos):
    if tx.block_as[Fire](pos):
        tx.set_block_runtime_id(pos, tx.block_registry()[].air_runtime_id())


def _splash_block[T: WorldTypes](mut tx: World[T], pos: Pos):
    # Go `SplashableBlock.Splash`: only campfires.
    if case .Some(c) = tx.block_as[Campfire](pos):
        if c.extinguished:
            return
        # Go `extinguish`; the cooking items come with block entities.
        tx.play_sound(pos.vec3_centre(), FireExtinguish())
        var e = c.copy()
        e.extinguished = True
        tx.set_block(pos, e)
