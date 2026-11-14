"""Firework rockets, ported from Dragonfly `server/entity/firework.go` and
`firework_behaviour.go`.

TODO(player): an attached firework follows its owner (a player) and the
explosion hurts living entities nearby; neither is in the world yet. Viewers
are not sent the explosion action yet (Go `FireworkExplosionAction`).
"""

from minecraft.nbt.nbt import TAG_COMPOUND
from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID

from ..block.cube.bbox import BBox
from ..item.firework import Firework as FireworkItem
from ..item.firework_shape import FireworkShape
from ..item.nbt import write_nbt
from ..item.stack import Stack
from ..mgl64 import Vec3
from ..world.entity import (
    EntityData,
    EntityHandle,
    EntityMovement,
    EntitySpawnOpts,
    ExplodableEntity,
    TickerEntity,
)
from ..world.sound.entity import (
    FireworkBlast,
    FireworkHugeBlast,
    FireworkTwinkle,
)
from ..world.world import World, WorldTypes
from .passive import PassiveBehaviour


struct Firework(Copyable, Defaultable, ExplodableEntity, TickerEntity):
    """A flying firework rocket (Go `FireworkType` with a
    `FireworkBehaviour`)."""

    comptime IDENTIFIER: StaticString = "minecraft:fireworks_rocket"
    """Go `EncodeEntity`."""

    var firework: FireworkItem
    """The firework item (Go `Firework`)."""
    var owner: UUID
    """Go `Owner`."""
    var sideways_velocity_multiplier: Float64
    """Go `SidewaysVelocityMultiplier`."""
    var upwards_acceleration: Float64
    """Go `UpwardsAcceleration`."""
    var attached: Bool
    """Go `Attached`."""
    var passive: PassiveBehaviour
    """No gravity or drag; exists for the firework's duration."""

    def __init__(out self):
        """Creates a rocket of a default firework flying for no time."""
        self = Self(FireworkItem(), 0)

    def __init__(
        out self,
        firework: FireworkItem,
        duration_ms: Int,
        sideways_velocity_multiplier: Float64 = 1.15,
        upwards_acceleration: Float64 = 0.04,
        attached: Bool = False,
        owner: UUID = UUID(),
    ):
        """Creates a rocket that flies for `duration_ms` (Go `newFirework`;
        `spawn_firework` draws Go's randomised duration)."""
        self.firework = firework.copy()
        self.owner = owner
        self.sideways_velocity_multiplier = sideways_velocity_multiplier
        self.upwards_acceleration = upwards_acceleration
        self.attached = attached
        self.passive = PassiveBehaviour(0, 0, duration_ms)

    def bbox(self, data: EntityData) -> BBox:
        """Returns Go's `BBox`, an empty box."""
        return BBox()

    def encode_nbt(self, data: EntityData, mut tree: Tree, tag: Tag) raises:
        """Writes the firework item (Go `EncodeNBT`, the item as disk NBT)."""
        var s = Stack(self.firework, 1)
        var enc = self.firework.encode_item()
        var it = tree.put_compound(tag, "Item")
        _ = tree.put_string(it, "Name", enc.name)
        _ = tree.put_short(it, "Damage", enc.meta)
        _ = tree.put_byte(it, "Count", 1)
        var t = write_nbt(s)
        if len(t.children(t.root())) > 0:
            _ = tree.put_tree(it, "tag", t, t.root())

    @staticmethod
    def decode_nbt(tree: Tree, tag: Tag, mut data: EntityData) raises -> Self:
        """Reads the firework item (Go `DecodeNBT`); the duration is the
        firework's own, as Go draws it again."""
        var f = FireworkItem()
        if case .Some(it) = tree.get(tag, "Item"):
            if tree.type_of(it) == TAG_COMPOUND:
                if case .Some(t) = tree.get(it, "tag"):
                    f = f.decode_nbt(tree, t)
        var d = f.duration
        return Self(f, d)

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
        """Flies up and explodes (Go `Ent.Tick`, `PassiveBehaviour.Tick`,
        `FireworkBehaviour.tick` and `explode`)."""
        if data.pos.y() < Float64(tx.range().min()) and current % 10 == 0:
            _ = tx.remove_entity(id)
            return None
        data.fire_duration_ms = max(data.fire_duration_ms - 50, 0)
        var m = self.passive.step(data, tx, self.bbox(data))
        if not m:
            _ = tx.remove_entity(id)
            return None
        if self.attached and tx.has_entity(self.owner):
            data.pos = tx.entity(self.owner).value().data.pos
        else:
            data.vel = Vec3(
                data.vel.x() * self.sideways_velocity_multiplier,
                data.vel.y() + self.upwards_acceleration,
                data.vel.z() * self.sideways_velocity_multiplier,
            )
        if self.passive.expired(data):
            for e in self.firework.explosions:
                if e.shape == FireworkShape.HUGE_SPHERE:
                    tx.play_sound(data.pos, FireworkHugeBlast())
                else:
                    tx.play_sound(data.pos, FireworkBlast())
                if e.twinkle:
                    tx.play_sound(data.pos, FireworkTwinkle())
            # TODO(player): hurt living entities within 5 blocks.
        data.age_ms += 50
        return m


def spawn_firework[
    T: WorldTypes
](mut tx: World[T], pos: Vec3, vel: Vec3, firework: FireworkItem):
    """Launches a firework rocket (Go `NewFirework`); its flight time is
    the firework's duration plus up to 600 ms drawn from Go's global
    source (Go `RandomisedDuration`)."""
    var d = firework.duration + tx.global_rand().int_n(600)
    var state = T.Entities.try_wrap(Firework(firework, d))
    if not state:
        return
    var opts = EntitySpawnOpts()
    opts.position = pos
    opts.velocity = vel
    _ = tx.add_entity(EntityHandle[T.Entities](opts, state.take()))
