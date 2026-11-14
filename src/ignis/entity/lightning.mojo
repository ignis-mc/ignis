"""Lightning, ported from Dragonfly `server/entity/lightning.go`.

Go draws the lifetime and flicker from its global source; so does Ignis
(the world's stand-in). The strike hurts living entities around it and
sets them on fire (players, through their `PlayerProxy`).

Fixed from Dragonfly: Go's `spreadFire` adds a random offset to the
position and throws the result away, so its four extra fires all start at
the strike; here they start at the offsets.
"""

from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID

from ..block.cube.bbox import BBox
from ..block.cube.pos import Pos, pos_from_vec3
from ..block.fire import start_fire
from ..mgl64 import Vec3
from ..world.entity import EntityData, EntityMovement, TickerEntity
from ..world.sound.entity import Explosion, Thunder
from ..world.world import World, WorldTypes
from .damage import DAMAGE_LIGHTNING, AnyDamageSource
from .living_request import REQUEST_LIGHTNING, LivingRequest
from .passive import StationaryBehaviour


struct Lightning(Copyable, Defaultable, TickerEntity):
    """A lightning bolt (Go `LightningType` with its `lightningState`)."""

    comptime IDENTIFIER: StaticString = "minecraft:lightning_bolt"
    """Go `EncodeEntity`."""

    var damage: Float64
    """Go `Damage`."""
    var entity_fire_ms: Int
    """Go `EntityFireDuration`."""
    var block_fire: Bool
    """Go `BlockFire`."""
    var state: Int
    """Go `state`."""
    var lifetime: Int
    """Flickers left (Go `lifetime`); -1 until the first tick draws it."""
    var stationary: StationaryBehaviour
    """Exists for a second."""

    def __init__(out self):
        """Creates a bolt of 5 damage that starts fires (Go
        `NewLightning`)."""
        self = Self(5, True, 8000)

    def __init__(
        out self, damage: Float64, block_fire: Bool, entity_fire_ms: Int
    ):
        """Creates a bolt (Go `NewLightningWithDamage`); its lifetime is
        drawn on its first tick."""
        self.damage = damage
        self.entity_fire_ms = entity_fire_ms
        self.block_fire = block_fire
        self.state = 2
        self.lifetime = -1
        self.stationary = StationaryBehaviour(1000)

    def bbox(self, data: EntityData) -> BBox:
        """Returns Go's `BBox`, an empty box."""
        return BBox()

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
        """Strikes (Go `Ent.Tick`, `StationaryBehaviour.Tick`,
        `lightningState.tick`)."""
        if data.pos.y() < Float64(tx.range().min()) and current % 10 == 0:
            _ = tx.remove_entity(id)
            return None
        data.fire_duration_ms = max(data.fire_duration_ms - 50, 0)
        if self.stationary.closed():
            _ = tx.remove_entity(id)
            return None
        if self.lifetime < 0:
            # Go draws it in `NewLightningWithDamage`.
            self.lifetime = tx.global_rand().int_n(4) + 1
        if self.stationary.spawned(data):
            tx.play_sound(data.pos, Explosion())
            tx.play_sound(data.pos, Thunder())
        self.state -= 1
        if self.state < 0:
            if self.lifetime == 0:
                _ = tx.remove_entity(id)
                return None
            elif self.state < -tx.global_rand().int_n(10):
                self.lifetime -= 1
                self.state = 1
                if (
                    self.block_fire
                    and tx.difficulty().fire_spread_increase() >= 10
                ):
                    self._spread_fire(tx, pos_from_vec3(data.pos))
        if self.state > 0:
            self._deal_damage(data, tx)
        self.stationary.expire(data)
        data.age_ms += 50
        return None

    def _deal_damage[T: WorldTypes](self, data: EntityData, mut tx: World[T]):
        # Go `dealDamage`: living entities that are not dead yet.
        var box = (
            self.bbox(data)
            .grow_vec3(Vec3(3, 6, 3))
            .translate(data.pos.add(Vec3(0, 3, 0)))
        )
        for other in tx.entities_within(box):
            var e = tx.entity(other)
            if not e:
                continue
            ref st = e.value().state
            if not T.Entities.living(st) or T.Entities.living_health(st) <= 0:
                continue
            var r = LivingRequest(REQUEST_LIGHTNING)
            r.dmg = self.damage
            r.src = AnyDamageSource(DAMAGE_LIGHTNING)
            r.fire_ms = self.entity_fire_ms
            r.at_least = True
            _ = tx.living_request(other, r^)

    def _spread_fire[T: WorldTypes](self, mut tx: World[T], pos: Pos):
        # Go `spreadFire`.
        start_fire(tx, pos)
        for _ in range(4):
            ref r = tx.global_rand()
            var x = r.int_n(3) - 1
            var y = r.int_n(3) - 1
            var z = r.int_n(3) - 1
            start_fire(tx, pos.add(Pos(x, y, z)))
