"""Falling blocks, ported from Dragonfly `server/entity/falling_block.go`
and `falling_block_behaviour.go`, with the parts of `passive.go` and
`ent.go` they use.

The entity keeps the block's state next to the block, so that its NBT can
be written without the registry; a falling block loaded from disk has only
the state until its first tick resolves it. Anvils do not hurt entities
yet (no living entities are ported), but they still wear out when they fall
far, drawing from the world's stand-in for Go's global random source.
"""

from std.math import ceil, floor

from minecraft.nbt.nbt import TAG_COMPOUND, TAG_DOUBLE, TAG_INT, TAG_STRING
from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID

from ..block.air import Air
from ..block.anvil import Anvil
from ..block.anvil_type import AnvilType
from ..block.cube.bbox import BBox
from ..block.cube.pos import pos_from_vec3
from ..block.hash import AnyBlock
from ..item.stack import Stack
from ..world.block_registry import UNKNOWN_KIND
from ..world.block_state import BlockState, decode_properties
from ..world.chunk.encode import CURRENT_BLOCK_VERSION
from ..world.entity import (
    EntityData,
    EntityMovement,
    ExplodableEntity,
    NetworkEncodedEntity,
    TickerEntity,
)
from ..world.sound.block import AnvilLand
from ..world.world import World, WorldTypes
from .movement import MovementComputer
from ..mgl64 import Vec3

comptime FALLING_BLOCK_GRAVITY = 0.04
"""Go `fallingBlockConf.Gravity`."""
comptime FALLING_BLOCK_DRAG = 0.02
"""Go `fallingBlockConf.Drag`."""


struct FallingBlock(
    Copyable,
    ExplodableEntity,
    NetworkEncodedEntity,
    TickerEntity,
):
    """A block falling as an entity (Go `FallingBlockType` with a
    `FallingBlockBehaviour`)."""

    comptime IDENTIFIER: StaticString = "minecraft:falling_block"
    """Go `fallingBlockType.EncodeEntity`."""
    comptime NETWORK_IDENTIFIER: StaticString = "minecraft:falling_block"
    """Clients see a falling block."""
    comptime NETWORK_OFFSET = 0.49
    """Go `fallingBlockType.NetworkOffset`."""

    var block: AnyBlock
    """The block (Go `Block`); unknown for a loaded entity until its first
    tick."""
    var state: BlockState
    """The block's name and properties, for NBT."""
    var fall_distance: Float64
    """How far the block has fallen (Go `passive.fallDistance`)."""
    var mc: MovementComputer
    """The movement (Go's passive behaviour computer)."""
    var close: Bool
    """Set when the block landed (Go `passive.close`)."""

    def __init__(out self):
        """Creates a falling block of nothing."""
        self = Self(AnyBlock(kind=UNKNOWN_KIND, state=0), BlockState(""))

    def __init__(
        out self, block: AnyBlock, var state: BlockState, distance: Float64 = 0
    ):
        """Creates a falling block (Go `NewFallingBlock`)."""
        self.block = block
        self.state = state^
        self.fall_distance = distance
        self.mc = MovementComputer(FALLING_BLOCK_GRAVITY, FALLING_BLOCK_DRAG)
        self.mc.drag_before_gravity = True
        self.close = False

    def bbox(self, data: EntityData) -> BBox:
        """Returns Go's `fallingBlockType.BBox`."""
        return BBox.box(-0.49, 0, -0.49, 0.49, 0.98, 0.49)

    def encode_nbt(self, data: EntityData, mut tree: Tree, tag: Tag) raises:
        """Writes Go's `fallingBlockType.EncodeNBT` fields."""
        _ = tree.put_double(tag, "FallDistance", self.fall_distance)
        var b = tree.put_compound(tag, "FallingBlock")
        _ = tree.put_string(b, "name", self.state.name)
        var states = tree.put_compound(b, "states")
        for ref pr in self.state.properties.entries:
            if pr.value.tag == TAG_STRING:
                _ = tree.put_string(states, pr.key, pr.value.string)
            elif pr.value.tag == TAG_INT:
                _ = tree.put_int(states, pr.key, pr.value.int)
            else:
                _ = tree.put_byte(states, pr.key, UInt8(pr.value.int))
        _ = tree.put_int(b, "version", CURRENT_BLOCK_VERSION)

    @staticmethod
    def decode_nbt(tree: Tree, tag: Tag, mut data: EntityData) raises -> Self:
        """Reads Go's `fallingBlockType.DecodeNBT` fields; the block is
        resolved on the first tick."""
        var state = BlockState("")
        if case .Some(b) = tree.get(tag, "FallingBlock"):
            if tree.type_of(b) == TAG_COMPOUND:
                state.name = tree.get_string(b, "name")
                if case .Some(s) = tree.get(b, "states"):
                    if tree.type_of(s) == TAG_COMPOUND:
                        state.properties = decode_properties(tree, s)
        var distance = 0.0
        if case .Some(d) = tree.get(tag, "FallDistance"):
            if tree.type_of(d) == TAG_DOUBLE:
                distance = tree.as_double(d)
        return Self(AnyBlock(kind=UNKNOWN_KIND, state=0), state^, distance)

    def tick[
        T: WorldTypes
    ](
        mut self,
        id: UUID,
        mut data: EntityData,
        mut tx: World[T],
        current: Int64,
    ) -> Optional[EntityMovement]:
        """Falls and lands (Go `Ent.Tick`, `PassiveBehaviour.Tick` and
        `FallingBlockBehaviour.tick`)."""
        if data.pos.y() < Float64(tx.range().min()) and current % 10 == 0:
            _ = tx.remove_entity(id)
            return None
        data.fire_duration_ms = max(data.fire_duration_ms - 50, 0)
        if self.close:
            _ = tx.remove_entity(id)
            return None
        if self.block.kind == UNKNOWN_KIND:
            var br = tx.block_registry()
            var rid = br[].state_to_runtime_id(
                self.state.name, self.state.properties
            )
            if not rid:
                _ = tx.remove_entity(id)
                return None
            self.block = AnyBlock(
                kind=br[].kind(rid.value()), state=br[].state_hash(rid.value())
            )
        var old_y = data.pos.y()
        var m = self.mc.tick_movement(
            self.bbox(data), data.pos, data.vel, data.rot, tx
        )
        data.pos = m.pos
        data.vel = m.vel
        self.fall_distance = max(self.fall_distance - (m.pos.y() - old_y), 0)
        var bpos = pos_from_vec3(data.pos)
        if (
            T.Blocks.solidifies(self.block.kind, self.block.state, bpos, tx)
            or self.mc.on_ground
        ):
            self._solidify(data, tx)
        data.age_ms += 50
        return m

    def _solidify[T: WorldTypes](mut self, data: EntityData, mut tx: World[T]):
        # Go `solidify`.
        var bpos = pos_from_vec3(data.pos)
        if case .Some(a) = self.block.get[Anvil]():
            # Go `damageEntities`; there are no living entities to hurt yet.
            var dist = ceil(self.fall_distance - 1.0)
            if dist > 0:
                var dmg = min(floor(dist * 2), 40.0)
                if dmg > 0 and tx.global_rand().float64() < (dist + 1) * 0.05:
                    self.block = _break_anvil(a)
            tx.play_sound(bpos.vec3_centre(), AnvilLand())
        self.close = True
        var br = tx.block_registry()
        var rid = tx.block(bpos)
        if T.Blocks.replaceable_by(
            br[].kind(rid), br[].state_hash(rid), self.block
        ):
            if case .Some(r) = br[].runtime_id_of(
                self.block.kind, self.block.state
            ):
                tx.set_block_runtime_id(bpos, r)
        elif case .Some(it) = T.Blocks.block_item(
            self.block.kind, self.block.state
        ):
            tx.drop_item(bpos.vec3_middle(), Stack(it, 1))

    def explode(
        mut self, mut data: EntityData, src: Vec3, impact: Float64
    ) -> Bool:
        """Is pushed away (Go `PassiveBehaviour.Explode`)."""
        data.vel = data.vel.add(data.pos.sub(src).normalize().mul(impact))
        return False


def _break_anvil(a: Anvil) -> AnyBlock:
    # Go `Anvil.Break`.
    if a.type == AnvilType.UNDAMAGED:
        return AnyBlock(Anvil(type=AnvilType.SLIGHTLY_DAMAGED, facing=a.facing))
    if a.type == AnvilType.SLIGHTLY_DAMAGED:
        return AnyBlock(Anvil(type=AnvilType.VERY_DAMAGED, facing=a.facing))
    return AnyBlock(Air())
