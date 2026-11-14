"""Splashing potions, ported from Dragonfly `server/entity/splashable.go`.

TODO(player): Go applies the potion's effects to living entities within 4
blocks; there are none in the world yet. Splashing water puts out fire and
campfires, and lingering potions leave an area effect cloud, as in Go.
"""

from ..block.campfire import Campfire
from ..block.cube.bbox import BBox
from ..block.cube.face import Face
from ..block.cube.pos import Pos
from ..block.cube.trace.perform import TraceResult
from ..block.fire import Fire
from ..item.potion.potion import Potion
from ..world.entity import EntityData, EntityHandle, EntitySpawnOpts
from ..world.sound.block import FireExtinguish
from ..world.world import World, WorldTypes
from .area_effect_cloud import AreaEffectCloud


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
    if len(pot.effects()) > 0:
        # TODO(player): effects on living entities in range.
        pass
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
