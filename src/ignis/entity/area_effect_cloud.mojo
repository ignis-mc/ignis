"""Area effect clouds, ported from Dragonfly
`server/entity/area_effect_cloud.go` and `area_effect_cloud_behaviour.go`.

Every 10 ticks the cloud gives its effects to the living entities inside
(players, through their `PlayerProxy`), shrinking on each use. Viewers are
not sent its new radius yet (Go `ViewEntityState`).
"""

from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID

from ..block.cube.bbox import BBox
from ..internal.nbtconv.read import get_float32, get_int32
from ..item.potion.potion import Potion, from_id
from ..mgl64 import Vec3
from ..world.entity import EntityData, EntityMovement, TickerEntity
from ..world.world import World, WorldTypes
from .living_request import REQUEST_EFFECT, LivingRequest
from .passive import StationaryBehaviour


struct AreaEffectCloud(Copyable, Defaultable, TickerEntity):
    """A cloud of potion effects (Go `AreaEffectCloudType` with an
    `AreaEffectCloudBehaviour`)."""

    comptime IDENTIFIER: StaticString = "minecraft:area_effect_cloud"
    """Go `EncodeEntity`."""

    var potion: Potion
    """Go `Potion`."""
    var radius_use_growth: Float64
    """Go `RadiusUseGrowth`."""
    var radius_tick_growth: Float64
    """Go `RadiusTickGrowth`."""
    var duration_use_growth_ms: Int
    """Go `DurationUseGrowth`."""
    var reapplication_delay_ms: Int
    """Go `ReapplicationDelay`."""
    var stationary: StationaryBehaviour
    """Its lifetime (Go `stationary`)."""
    var duration_ms: Int
    """The duration left (Go `duration`)."""
    var radius: Float64
    """The current radius (Go `radius`)."""
    var targets: List[Tuple[UUID, Int]]
    """Entities given the effects, with the age at which they may get them
    again (Go `targets`)."""

    def __init__(out self):
        """Creates a cloud of water."""
        self = Self(Potion.WATER)

    def __init__(out self, p: Potion):
        """Creates a lingering potion's cloud (Go `NewAreaEffectCloud`)."""
        var delay = 2000
        for e in p.effects():
            if not e.lasting():
                delay = 0
                break
        self = Self(p, 0, -0.5, -0.005, 0, 0, delay)

    def __init__(
        out self,
        p: Potion,
        duration_ms: Int,
        radius_use_growth: Float64,
        radius_tick_growth: Float64,
        duration_use_growth_ms: Int,
        radius: Float64,
        reapplication_delay_ms: Int,
    ):
        """Creates a cloud (Go `AreaEffectCloudBehaviourConfig.New`); zero
        radius and duration mean 3 blocks and 30 seconds."""
        var d = duration_ms if duration_ms != 0 else 30000
        self.potion = p
        self.radius_use_growth = radius_use_growth
        self.radius_tick_growth = radius_tick_growth
        self.duration_use_growth_ms = duration_use_growth_ms
        self.reapplication_delay_ms = reapplication_delay_ms
        self.stationary = StationaryBehaviour(d)
        self.duration_ms = d
        self.radius = radius if radius != 0 else 3.0
        self.targets = List[Tuple[UUID, Int]]()

    def _apply_effects[
        T: WorldTypes
    ](mut self, data: EntityData, mut tx: World[T]):
        # Go `applyEffects` over `filter(EntitiesWithin(box))`.
        var box = self.bbox(data).translate(data.pos)
        for other in tx.entities_within(box):
            var e = tx.entity(other)
            if not e or not T.Entities.living(e.value().state):
                continue
            var targeted = False
            for t in self.targets:
                if t[0] == other:
                    targeted = True
            if targeted:
                continue
            var delta = e.value().data.pos.sub(data.pos)
            if Vec3(delta.x(), 0, delta.z()).len() > self.radius:
                continue
            var r = LivingRequest(REQUEST_EFFECT)
            for eff in self.potion.effects():
                if eff.lasting():
                    r.effects.append(eff.renewed(eff.duration() // 4))
                else:
                    r.effects.append(eff)
            _ = tx.living_request(other, r^)
            self.targets.append(
                (other, data.age_ms + self.reapplication_delay_ms)
            )
            # Go `subtractUseDuration` and `subtractUseRadius`.
            self.duration_ms += self.duration_use_growth_ms
            if self.duration_ms <= 0:
                self.stationary.close = True
            self.radius += self.radius_use_growth
            if self.radius <= 0.5:
                self.stationary.close = True

    def bbox(self, data: EntityData) -> BBox:
        """Returns Go's `BBox`, which grows and shrinks with the radius."""
        var r = self.radius
        return BBox.box(-r, 0, -r, r, 0.5, r)

    def encode_nbt(self, data: EntityData, mut tree: Tree, tag: Tag) raises:
        """Writes Go's `EncodeNBT` fields."""
        _ = tree.put_int(tag, "PotionId", Int32(self.potion.uint8()))
        _ = tree.put_int(
            tag, "ReapplicationDelay", Int32(self.reapplication_delay_ms // 50)
        )
        _ = tree.put_float(
            tag, "RadiusPerTick", Float32(self.radius_tick_growth)
        )
        _ = tree.put_float(tag, "RadiusOnUse", Float32(self.radius_use_growth))
        _ = tree.put_int(
            tag, "DurationOnUse", Int32(self.duration_use_growth_ms // 50)
        )
        _ = tree.put_float(tag, "Radius", Float32(self.radius))
        _ = tree.put_int(tag, "Duration", Int32(self.duration_ms // 50))

    @staticmethod
    def decode_nbt(tree: Tree, tag: Tag, mut data: EntityData) raises -> Self:
        """Reads Go's `DecodeNBT` fields."""
        return Self(
            from_id(get_int32(tree, tag, "PotionId")),
            Int(get_int32(tree, tag, "Duration")) * 50,
            Float64(get_float32(tree, tag, "RadiusOnUse")),
            Float64(get_float32(tree, tag, "RadiusPerTick")),
            Int(get_int32(tree, tag, "DurationOnUse")) * 50,
            Float64(get_float32(tree, tag, "Radius")),
            Int(get_int32(tree, tag, "ReapplicationDelay")) * 50,
        )

    def tick[
        T: WorldTypes
    ](
        mut self,
        id: UUID,
        mut data: EntityData,
        mut tx: World[T],
        current: Int64,
    ) -> Optional[EntityMovement]:
        """Shrinks and expires (Go `Ent.Tick`, `AreaEffectCloudBehaviour.Tick`).
        """
        if data.pos.y() < Float64(tx.range().min()) and current % 10 == 0:
            _ = tx.remove_entity(id)
            return None
        data.fire_duration_ms = max(data.fire_duration_ms - 50, 0)
        if self.stationary.closed():
            _ = tx.remove_entity(id)
            return None
        self.stationary.expire(data)
        if not self.stationary.close and data.age_ms >= 500:
            # Go `subtractTickRadius`.
            self.radius += self.radius_tick_growth
            if self.radius < 0.5:
                self.stationary.close = True
            if (data.age_ms // 50) % 10 == 0:
                var k = 0
                while k < len(self.targets):
                    if data.age_ms >= self.targets[k][1]:
                        _ = self.targets.pop(k)
                        continue
                    k += 1
                self._apply_effects(data, tx)
        data.age_ms += 50
        return None
