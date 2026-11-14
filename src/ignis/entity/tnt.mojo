"""Lit TNT, ported from Dragonfly `server/entity/tnt.go`.

Go explodes with a generator seeded from the clock; Ignis seeds it from the
world's stand-in for Go's global source.
"""

from std.math import cos, pi, sin

from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID

from ..block.cube.bbox import BBox
from ..block.cube.pos import Pos
from ..block.explosion import ExplosionConfig, ExplosionSource, explode
from ..internal.nbtconv.read import tick_duration_int16
from ..internal.rand import Rand
from ..mgl64 import Vec3
from ..world.entity import (
    EntityData,
    EntityHandle,
    EntityMovement,
    EntitySpawnOpts,
    ExplodableEntity,
    NetworkEncodedEntity,
    TickerEntity,
)
from ..world.sound.block import TNT as TNTSound
from ..world.world import World, WorldTypes
from .passive import PassiveBehaviour


struct TNT(
    Copyable, Defaultable, ExplodableEntity, NetworkEncodedEntity, TickerEntity
):
    """Lit TNT that explodes when its fuse runs out (Go `TNTType` with a
    `PassiveBehaviour`)."""

    comptime IDENTIFIER: StaticString = "minecraft:tnt"
    """Go `EncodeEntity`."""
    comptime NETWORK_IDENTIFIER: StaticString = "minecraft:tnt"
    """Clients see TNT."""
    comptime NETWORK_OFFSET = 0.49
    """Go `NetworkOffset`."""

    var passive: PassiveBehaviour
    """Gravity 0.04, drag 0.02, existence = fuse."""

    def __init__(out self):
        """Creates TNT with a four second fuse."""
        self = Self(4000)

    def __init__(out self, fuse_ms: Int):
        """Creates TNT with a fuse (Go `NewTNT`)."""
        self.passive = PassiveBehaviour(0.04, 0.02, fuse_ms)

    def bbox(self, data: EntityData) -> BBox:
        """Returns Go's `BBox`."""
        return BBox.box(-0.49, 0, -0.49, 0.49, 0.98, 0.49)

    def encode_nbt(self, data: EntityData, mut tree: Tree, tag: Tag) raises:
        """Writes the fuse in ticks (Go `EncodeNBT`)."""
        _ = tree.put_short(
            tag, "Fuse", Int16(min(self.passive.fuse_ms // 50, Int(Int16.MAX)))
        )

    @staticmethod
    def decode_nbt(tree: Tree, tag: Tag, mut data: EntityData) raises -> Self:
        """Reads the fuse (Go `DecodeNBT`)."""
        return Self(tick_duration_int16(tree, tag, "Fuse"))

    def explode(
        mut self, mut data: EntityData, src: Vec3, impact: Float64
    ) -> Bool:
        """Is pushed away (Go `PassiveBehaviour.Explode`)."""
        data.vel = data.vel.add(data.pos.sub(src).normalize().mul(impact))
        return False

    def tick[
        T: WorldTypes
    ](
        mut self,
        id: UUID,
        mut data: EntityData,
        mut tx: World[T],
        current: Int64,
    ) -> Optional[EntityMovement]:
        """Falls and explodes when the fuse runs out (Go `Ent.Tick`,
        `PassiveBehaviour.Tick`, `explodeTNT`)."""
        if data.pos.y() < Float64(tx.range().min()) and current % 10 == 0:
            _ = tx.remove_entity(id)
            return None
        data.fire_duration_ms = max(data.fire_duration_ms - 50, 0)
        var m = self.passive.step(data, tx, self.bbox(data))
        if not m:
            _ = tx.remove_entity(id)
            return None
        if self.passive.expired(data):
            ref g = tx.global_rand()
            var c = ExplosionConfig(Rand(g.uint64(), g.uint64()))
            c.item_drop_chance = 1
            explode(tx, ExplosionSource(data.pos, 4), c)
        data.age_ms += 50
        return m


def spawn_tnt[T: WorldTypes](mut tx: World[T], pos: Pos, fuse_ms: Int):
    """Replaces the block at `pos` with lit TNT (Go `spawnTnt` and
    `NewTNT`); the push it starts with is drawn from Go's global source."""
    tx.play_sound(pos.vec3_centre(), TNTSound())
    tx.set_block_runtime_id(pos, tx.block_registry()[].air_runtime_id())
    var state = T.Entities.try_wrap(TNT(fuse_ms))
    if not state:
        return
    var angle = tx.global_rand().float64() * pi * 2
    var opts = EntitySpawnOpts()
    opts.position = pos.vec3_centre()
    opts.velocity = Vec3(-sin(angle) * 0.02, 0.1, -cos(angle) * 0.02)
    _ = tx.add_entity(EntityHandle[T.Entities](opts, state.take()))
