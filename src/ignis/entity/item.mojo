"""Item entities, ported from Dragonfly `server/entity/item.go` and
`item_behaviour.go`, with the parts of `passive.go` (`PassiveBehaviour`)
and `ent.go` (`Ent.Tick`) they use.

Differences from Go:

- Picking up and merging need the players and the concrete entity set, so
  the server does them each tick (`Server`'s item pass); this type ticks
  physics, the pickup delay and despawning.
- Encoding the item needs the registries, which entity NBT callbacks do not
  get: the entity keeps the stack's disk NBT (`item_nbt`) next to the
  stack. A loaded item entity has only the NBT until the server resolves
  the stack (`ItemBehaviour.resolved`).
- Hoppers, explosions and portals are not ported.
"""

from minecraft.nbt.nbt import TAG_COMPOUND, TAG_LONG
from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID

from ..block.cube.bbox import BBox
from ..item.stack import Stack
from ..world.entity import (
    EntityData,
    EntityMovement,
    ExplodableEntity,
    NetworkEncodedEntity,
    TickerEntity,
)
from ..world.world import World, WorldTypes
from .movement import MovementComputer
from ..mgl64 import Vec3

comptime ITEM_GRAVITY = 0.04
"""Go `itemConf.Gravity`."""
comptime ITEM_DRAG = 0.02
"""Go `itemConf.Drag`."""
comptime DEFAULT_PICKUP_DELAY_TICKS = 10
"""Go's default pickup delay of half a second."""
comptime EXISTENCE_DURATION_MS = 5 * 60 * 1000
"""Go's default existence duration of five minutes."""
comptime _MAX_DELAY_TICKS = 32767
"""A delay at or above `math.MaxInt16` ticks never runs out."""


struct ItemBehaviour(
    Copyable,
    ExplodableEntity,
    NetworkEncodedEntity,
    TickerEntity,
):
    """An item stack lying in the world (Go `ItemType` with an
    `ItemBehaviour`)."""

    comptime IDENTIFIER: StaticString = "minecraft:item"
    """Go `itemType.EncodeEntity`."""
    comptime NETWORK_IDENTIFIER: StaticString = "minecraft:item"
    """Clients see an item."""
    comptime NETWORK_OFFSET = 0.125
    """Go `itemType.NetworkOffset`."""

    var item: Stack
    """The stack (Go `Item`); empty for a loaded entity until resolved."""
    var item_nbt: Tree
    """The stack as disk NBT (Go `WriteNBT(i, true)`)."""
    var pickup_delay_ticks: Int
    """Ticks before the item may be picked up (Go `pickupDelay`)."""
    var mc: MovementComputer
    """The movement (Go's passive behaviour computer)."""
    var close: Bool
    """Set when the existence duration ran out (Go `PassiveBehaviour`)."""

    def __init__(out self):
        """Creates an empty item entity."""
        self = Self(Stack(), Tree())

    def __init__(
        out self,
        it: Stack,
        var nbt: Tree,
        pickup_delay_ticks: Int = DEFAULT_PICKUP_DELAY_TICKS,
    ):
        """Creates an item entity of a stack and its disk NBT (Go
        `NewItemPickupDelay`); the count is capped at the max count."""
        var s = it.copy()
        if s.count() > s.max_count():
            s = s.grow(s.max_count() - s.count())
        self.item = s^
        self.item_nbt = nbt^
        self.pickup_delay_ticks = pickup_delay_ticks
        if self.pickup_delay_ticks == 0:
            self.pickup_delay_ticks = DEFAULT_PICKUP_DELAY_TICKS
        self.mc = MovementComputer(ITEM_GRAVITY, ITEM_DRAG)
        self.mc.drag_before_gravity = True
        self.close = False

    def resolved(self) -> Bool:
        """Reports whether the stack is known (not only its NBT)."""
        return not self.item.empty()

    def can_pick_up(self) -> Bool:
        """Reports whether the pickup delay has run out (Go's
        `pickupDelay == 0`)."""
        return self.pickup_delay_ticks == 0

    def bbox(self, data: EntityData) -> BBox:
        """Returns Go's `itemType.BBox`."""
        return BBox.box(-0.125, 0, -0.125, 0.125, 0.25, 0.125)

    def encode_nbt(self, data: EntityData, mut tree: Tree, tag: Tag) raises:
        """Writes Go's `itemType.EncodeNBT` fields."""
        _ = tree.put_short(tag, "Health", 5)
        _ = tree.put_long(tag, "PickupDelay", Int64(self.pickup_delay_ticks))
        _ = tree.put_tree(tag, "Item", self.item_nbt, self.item_nbt.root())

    @staticmethod
    def decode_nbt(tree: Tree, tag: Tag, mut data: EntityData) raises -> Self:
        """Reads Go's `itemType.DecodeNBT` fields; the stack is resolved
        later from `item_nbt`."""
        var nbt = Tree()
        if case .Some(i) = tree.get(tag, "Item"):
            if tree.type_of(i) == TAG_COMPOUND:
                for c in tree.children(i):
                    _ = nbt.put_tree(nbt.root(), tree.name(c), tree, c)
        var delay = 0
        if case .Some(d) = tree.get(tag, "PickupDelay"):
            if tree.type_of(d) == TAG_LONG:
                delay = Int(tree.as_long(d))
        return Self(Stack(), nbt^, delay)

    def tick[
        T: WorldTypes
    ](
        mut self,
        id: UUID,
        mut data: EntityData,
        mut tx: World[T],
        current: Int64,
    ) -> Optional[EntityMovement]:
        """Ticks the item (Go `Ent.Tick`, `PassiveBehaviour.Tick` and
        `ItemBehaviour.tick`): it falls and collides with blocks, counts
        down its pickup delay and despawns after five minutes or below the
        world."""
        if data.pos.y() < Float64(tx.range().min()) and current % 10 == 0:
            _ = tx.remove_entity(id)
            return None
        data.fire_duration_ms = max(data.fire_duration_ms - 50, 0)
        if self.close:
            _ = tx.remove_entity(id)
            return None
        var m = self.mc.tick_movement(
            self.bbox(data), data.pos, data.vel, data.rot, tx
        )
        data.pos = m.pos
        data.vel = m.vel
        if (
            self.pickup_delay_ticks > 0
            and self.pickup_delay_ticks < _MAX_DELAY_TICKS
        ):
            self.pickup_delay_ticks -= 1
        if data.age_ms > EXISTENCE_DURATION_MS:
            self.close = True
        data.age_ms += 50
        return m

    def explode(
        mut self, mut data: EntityData, src: Vec3, impact: Float64
    ) -> Bool:
        """Is destroyed by an explosion that reaches it (Go
        `ItemBehaviour.Explode`). TODO: blast-proof (netherite) items
        survive in Go."""
        return impact > 0
