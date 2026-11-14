"""Arrows, ported from Dragonfly `server/entity/arrow.go`.

Fixed from Dragonfly: `StuckToBlockPos` is written as an int array (as Go
writes it) and read back as one; Go reads it as a list and loses it."""

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
from ..block.cube.pos import Pos
from ..internal.nbtconv.read import get_bool, get_float32, get_int32, get_uint8
from ..item.arrow import Arrow as ArrowItem
from ..item.potion.potion import from_id
from ..item.stack import Stack
from ..world.sound.item import ArrowHit
from ..mgl64 import Vec3

comptime PUNCH_KNOCK_BACK_MULTIPLIER = 0.25
"""Go `enchantment.Punch.KnockBackMultiplier`."""


struct Arrow(
    Copyable,
    Defaultable,
    ExplodableEntity,
    TickerEntity,
):
    """A shot arrow (Go `ArrowType`)."""

    comptime IDENTIFIER: StaticString = "minecraft:arrow"
    """Go `EncodeEntity`."""

    var proj: ProjectileBehaviour
    """The projectile's movement and collisions."""

    def __init__(out self):
        """Creates the projectile without an owner."""
        self.proj = ProjectileBehaviour(
            0.05, 0.01, damage=2.0, survive_block_collision=True
        )

    def bbox(self, data: EntityData) -> BBox:
        """Returns Go's `BBox`."""
        return BBox.box(-0.125, 0, -0.125, 0.125, 0.25, 0.125)

    def encode_nbt(self, data: EntityData, mut tree: Tree, tag: Tag) raises:
        """Writes Go's `EncodeNBT` fields."""
        _ = tree.put_float(tag, "Damage", Float32(self.proj.damage))
        _ = tree.put_byte(
            tag,
            "enchantPunch",
            UInt8(
                Int(
                    self.proj.knock_back_force_addend
                    / PUNCH_KNOCK_BACK_MULTIPLIER
                )
            ),
        )
        _ = tree.put_int(tag, "auxValue", Int32(self.proj.potion.uint8()) + 1)
        _ = tree.put_byte(
            tag,
            "player",
            UInt8(1) if not self.proj.disable_pickup else UInt8(0),
        )
        _ = tree.put_byte(
            tag,
            "isCreative",
            UInt8(1) if self.proj.pickup_item.empty() else UInt8(0),
        )
        if self.proj.collided:
            var p = self.proj.collision_pos
            var v: List[Int32] = [Int32(p.x()), Int32(p.y()), Int32(p.z())]
            _ = tree.put_int_array(tag, "StuckToBlockPos", v)

    @staticmethod
    def decode_nbt(tree: Tree, tag: Tag, mut data: EntityData) raises -> Self:
        """Reads Go's `DecodeNBT` fields."""
        var a = Self()
        a.proj.damage = Float64(get_float32(tree, tag, "Damage"))
        a.proj.potion = from_id(get_int32(tree, tag, "auxValue") - 1)
        a.proj.disable_pickup = not get_bool(tree, tag, "player")
        if not get_bool(tree, tag, "isCreative"):
            a.proj.pickup_item = Stack(ArrowItem(tip=a.proj.potion), 1)
        a.proj.knock_back_force_addend = PUNCH_KNOCK_BACK_MULTIPLIER * Float64(
            get_uint8(tree, tag, "enchantPunch")
        )
        if tree.has(tag, "StuckToBlockPos"):
            var v = tree.get_int_array(tag, "StuckToBlockPos")
            if len(v) == 3:
                var p = Pos(Int(v[0]), Int(v[1]), Int(v[2]))
                a.proj.collision_pos = p
                a.proj.collided = p != Pos(0, 0, 0)
        return a^

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
            tx.play_sound(at, ArrowHit())
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
