"""Experience orbs, ported from Dragonfly `server/entity/experience_orb.go`
and `experience_orb_behaviour.go`.

Orbs look for an experience collector (a player, through its
`PlayerProxy`) within 8 blocks once a second, fly to it and are collected on
touching it. Go's search interval is wall-clock time; here it is the orb's
age. Dragonfly does not merge orbs.
"""

from std.math import sqrt

from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID

from ..block.cube.bbox import BBox
from ..internal.nbtconv.read import get_int32
from ..mgl64 import Vec3
from ..world.entity import (
    EntityData,
    EntityHandle,
    EntityMovement,
    EntitySpawnOpts,
    ExplodableEntity,
    TickerEntity,
)
from ..world.world import World, WorldTypes
from .passive import PassiveBehaviour

comptime ORB_SPLIT_SIZES: List[Int] = [
    2477,
    1237,
    617,
    307,
    149,
    73,
    37,
    17,
    7,
    3,
    1,
]
"""Go `orbSplitSizes`."""


struct ExperienceOrb(
    Copyable,
    Defaultable,
    ExplodableEntity,
    TickerEntity,
):
    """An orb of experience (Go `ExperienceOrbType` with an
    `ExperienceOrbBehaviour`)."""

    comptime IDENTIFIER: StaticString = "minecraft:xp_orb"
    """Go `EncodeEntity`."""

    var experience: Int
    """The experience it gives (Go `Experience`)."""
    var passive: PassiveBehaviour
    """Its movement: gravity 0.04, drag 0.02, five minutes."""
    var target: UUID
    """The collector it follows; zero for none (Go `target`)."""
    var last_search_ms: Int
    """The age at which it last looked for a target (Go `lastSearch`)."""

    def __init__(out self):
        """Creates an orb of 1 experience."""
        self = Self(1)

    def __init__(out self, experience: Int):
        """Creates an orb (Go `ExperienceOrbBehaviourConfig.New`)."""
        self.experience = experience if experience != 0 else 1
        self.passive = PassiveBehaviour(0.04, 0.02, 5 * 60 * 1000)
        self.target = UUID()
        self.last_search_ms = -1000

    def bbox(self, data: EntityData) -> BBox:
        """Returns Go's `BBox`."""
        return BBox.box(-0.125, 0, -0.125, 0.125, 0.25, 0.125)

    def encode_nbt(self, data: EntityData, mut tree: Tree, tag: Tag) raises:
        """Writes Go's `EncodeNBT` fields."""
        _ = tree.put_int(tag, "Value", Int32(self.experience))

    @staticmethod
    def decode_nbt(tree: Tree, tag: Tag, mut data: EntityData) raises -> Self:
        """Reads Go's `DecodeNBT` fields."""
        return Self(Int(get_int32(tree, tag, "Value")))

    def tick[
        T: WorldTypes
    ](
        mut self,
        id: UUID,
        mut data: EntityData,
        mut tx: World[T],
        current: Int64,
    ) -> Optional[EntityMovement]:
        """Falls and expires (Go `Ent.Tick`, `PassiveBehaviour.Tick`)."""
        if data.pos.y() < Float64(tx.range().min()) and current % 10 == 0:
            _ = tx.remove_entity(id)
            return None
        data.fire_duration_ms = max(data.fire_duration_ms - 50, 0)
        var m = self.passive.step(data, tx, self.bbox(data))
        if not m:
            _ = tx.remove_entity(id)
            return None
        if self._follow(data, tx, current):
            _ = tx.remove_entity(id)
            return None
        _ = self.passive.expired(data)
        data.age_ms += 50
        return m

    def _follow[
        T: WorldTypes
    ](mut self, mut data: EntityData, mut tx: World[T], current: Int64) -> Bool:
        # Go `tick`: returns True if the target collected the orb.
        var pos = data.pos
        var target = tx.entity(self.target)
        var has = False
        if case .Some(ref t) = target:
            has = (
                T.Entities.living_health(t.state) > 0
                and pos.sub(t.data.pos).len() <= 8
            )
        if not has and data.age_ms - self.last_search_ms >= 1000:
            # Go `findTarget`.
            self.target = UUID()
            var follow = BBox.box(-8, -8, -8, 8, 8, 8).translate(pos)
            for other in tx.entities_within(follow):
                var o = tx.entity(other)
                if o and T.Entities.can_collect_experience(
                    o.value().state, current
                ):
                    self.target = other
                    break
            self.last_search_ms = data.age_ms
            return False
        if not has:
            return False
        # Go `moveToTarget`; collectors are players, whose eyes are 1.62 up.
        ref t = target.value()
        var dst = t.data.pos.add(Vec3(0, 1.62 / 2, 0))
        var diff = dst.sub(pos).mul(0.125)
        var dist = diff.len_sqr()
        if dist < 1:
            var f = 1 - sqrt(dist)
            data.vel = data.vel.add(diff.normalize().mul(0.2 * f * f))
        var mine = self.bbox(data).translate(pos)
        if not mine.intersects_with(t.bbox().translate(t.data.pos)):
            return False
        if not T.Entities.can_collect_experience(t.state, current):
            return False
        tx.collect_experience(self.target, self.experience, current)
        return True

    def explode(
        mut self, mut data: EntityData, src: Vec3, impact: Float64
    ) -> Bool:
        """Is pushed away (Go `PassiveBehaviour.Explode`)."""
        data.vel = data.vel.add(data.pos.sub(src).normalize().mul(impact))
        return False


def experience_orb_sizes(amount_in: Int) -> List[Int]:
    """Splits experience into orb sizes (Go `NewExperienceOrbs`)."""
    var out = List[Int]()
    var amount = amount_in
    while amount > 0:
        for size in materialize[ORB_SPLIT_SIZES]():
            if amount >= size:
                out.append(size)
                amount -= size
                break
    return out^


def spawn_experience_orbs[
    T: WorldTypes
](mut tx: World[T], pos: Vec3, amount: Int):
    """Adds orbs holding `amount` experience at a position, thrown in random
    directions from Go's global source (Go `NewExperienceOrbs`)."""
    for size in experience_orb_sizes(amount):
        ref r = tx.global_rand()
        var x = (r.float64() * 0.2 - 0.1) * 2
        var y = r.float64() * 0.4
        var z = (r.float64() * 0.2 - 0.1) * 2
        var state = T.Entities.try_wrap(ExperienceOrb(size))
        if not state:
            return
        var opts = EntitySpawnOpts()
        opts.position = pos
        opts.velocity = Vec3(x, y, z)
        _ = tx.add_entity(EntityHandle[T.Entities](opts, state.take()))
