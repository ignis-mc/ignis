"""Eggs, ported from Dragonfly `server/entity/egg.go`. Dragonfly does not
hatch chicks."""

from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID

from ..block.cube.bbox import BBox
from ..world.entity import (
    EntityData,
    EntityMovement,
    ExplodableEntity,
    TickerEntity,
)
from ..world.world import World, WorldTypes
from .projectile import ProjectileBehaviour
from ..world.particle.entity import EggSmash
from ..mgl64 import Vec3


struct Egg(
    Copyable,
    Defaultable,
    ExplodableEntity,
    TickerEntity,
):
    """A thrown egg (Go `EggType`)."""

    comptime IDENTIFIER: StaticString = "minecraft:egg"
    """Go `EncodeEntity`."""

    var proj: ProjectileBehaviour
    """The projectile's movement and collisions."""

    def __init__(out self):
        """Creates the projectile without an owner."""
        self.proj = ProjectileBehaviour(0.03, 0.01, damage=0)

    def bbox(self, data: EntityData) -> BBox:
        """Returns Go's `BBox`."""
        return BBox.box(-0.125, 0, -0.125, 0.125, 0.25, 0.125)

    def encode_nbt(self, data: EntityData, mut tree: Tree, tag: Tag) raises:
        """Writes nothing (Go `EncodeNBT`)."""
        pass

    @staticmethod
    def decode_nbt(tree: Tree, tag: Tag, mut data: EntityData) raises -> Self:
        """Reads nothing (Go `DecodeNBT`)."""
        return Self()

    def tick[
        T: WorldTypes
    ](
        mut self,
        id: UUID,
        mut data: EntityData,
        mut tx: World[T],
        current: Int64,
    ) -> Optional[EntityMovement]:
        """Flies and hits (Go `Ent.Tick` and `ProjectileBehaviour.Tick`)."""
        if data.pos.y() < Float64(tx.range().min()) and current % 10 == 0:
            _ = tx.remove_entity(id)
            return None
        data.fire_duration_ms = max(data.fire_duration_ms - 50, 0)
        var st = self.proj.step(id, data, tx, self.bbox(data))
        if not st:
            _ = tx.remove_entity(id)
            return None
        var s = st.take()
        if s.hit:
            var at = s.hit.value().position()
            for _ in range(6):
                tx.add_particle(at, EggSmash())
            if self.proj.hit_target(data, tx, s):
                pass
                self.proj.finish()
        data.age_ms += 50
        return s.movement

    def explode(
        mut self, mut data: EntityData, src: Vec3, impact: Float64
    ) -> Bool:
        """Is pushed away (Go `ProjectileBehaviour.Explode`)."""
        data.vel = data.vel.add(data.pos.sub(src).normalize().mul(impact))
        return False
