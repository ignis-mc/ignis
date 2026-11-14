"""The world viewer of a session: the `world.Viewer` methods of Dragonfly's
`session.Session` (`ViewChunk` in `chunk.go`, `ViewTime` and
`ViewTimeCycle` in `world.go`).

The world owns its loaders' viewers (`docs/architecture.md`), so the session
cannot be its own viewer as in Go. Its `SessionViewer` shares a
`PacketQueue` with it through an `ArcPointer`: what the world shows the
viewer is encoded into the queue, and the session sends the queue in order
with its own packets.
"""

from std.collections import Dict
from std.memory import ArcPointer

from minecraft.protocol.block_pos import BlockPos
from minecraft.protocol.math import Vec3 as ProtocolVec3
from minecraft.protocol.entity_metadata import (
    ENTITY_DATA_FLAG_HAS_GRAVITY,
    ENTITY_DATA_KEY_FLAGS,
    ENTITY_DATA_KEY_HEIGHT,
    ENTITY_DATA_KEY_SCALE,
    ENTITY_DATA_KEY_WIDTH,
    new_entity_metadata,
)
from minecraft.protocol.packet.add_item_actor import AddItemActor
from minecraft.protocol.packet.move_actor_absolute import (
    MOVE_FLAG_ON_GROUND,
    MoveActorAbsolute,
)
from minecraft.protocol.packet.remove_actor import RemoveActor
from minecraft.protocol.packet.set_actor_motion import SetActorMotion
from minecraft.protocol.packet.update_block import (
    BLOCK_UPDATE_NETWORK,
    UpdateBlock,
)

from minecraft.protocol.game_rule import GameRule, GameRuleValue
from minecraft.protocol.packet.game_rules_changed import GameRulesChanged
from minecraft.protocol.packet.packet import Packet, encode_packet
from minecraft.protocol.packet.set_time import SetTime

from ..block.cube.pos import Pos
from ..block.cube.rotation import Rotation
from ..entity.item import ItemBehaviour
from ..item.nbt import read_disk_nbt
from ..entity.register import VanillaEntities
from ..mgl64 import Vec3
from ..world.block_registry import BasicBlockRegistry
from ..world.chunk.chunk import Chunk
from ..world.entity import EntityHandle, EntityTypes
from ..world.item import ItemRegistry
from ..world.dimension import Dimension
from ..world.position import ChunkPos
from ..world.viewer import Viewer
from .chunk import network_chunk
from .inventory import instance_from_item


struct PacketQueue(Defaultable, Movable):
    """Encoded packets waiting to be written to a session's connection."""

    var packets: List[List[UInt8]]
    """The packets, header included, oldest first."""
    var error: Optional[String]
    """The first encoding error, if any."""
    var entity_ids: Dict[String, UInt64]
    """The runtime IDs of the entities the session knows, by UUID text (Go
    `entityRuntimeIDs`), shared by the session and its viewer."""
    var next_entity_id: UInt64
    """The last runtime ID handed out (Go `currentEntityRuntimeID`)."""
    var blocks: ArcPointer[BasicBlockRegistry]
    """The block registry, for block items."""
    var items: ArcPointer[ItemRegistry]
    """The item registry stacks are encoded with."""

    def __init__(out self):
        """Creates an empty queue without registries."""
        self = Self(
            ArcPointer(BasicBlockRegistry()), ArcPointer(ItemRegistry())
        )

    def __init__(
        out self,
        blocks: ArcPointer[BasicBlockRegistry],
        items: ArcPointer[ItemRegistry],
    ):
        """Creates an empty queue encoding stacks with these registries."""
        self.packets = List[List[UInt8]]()
        self.error = None
        self.entity_ids = Dict[String, UInt64]()
        self.next_entity_id = 1
        self.blocks = blocks
        self.items = items

    def new_entity_id(mut self, key: String) -> UInt64:
        """Assigns the next runtime ID to an entity (Go `ViewEntity`)."""
        self.next_entity_id += 1
        self.entity_ids[key] = self.next_entity_id
        return self.next_entity_id

    def push[P: Packet](mut self, mut pk: P):
        """Encodes and queues a packet."""
        try:
            self.packets.append(encode_packet(pk))
        except e:
            if not self.error:
                self.error = String(e)


struct SessionViewer(Viewer):
    """Shows a session what its chunk loader's world does."""

    var queue: ArcPointer[PacketQueue]
    """The queue shared with the session."""

    def __init__(out self, queue: ArcPointer[PacketQueue]):
        """Creates a viewer writing into a session's queue."""
        self.queue = queue

    def view_chunk(mut self, pos: ChunkPos, dim: Dimension, c: Chunk):
        """Sends a chunk's biomes; the client then requests its sub-chunks
        (Go `ViewChunk` and `sendNetworkChunk`)."""
        var pk = network_chunk(pos, Int32(dim.id), c)
        self.queue[].push(pk)

    def view_time(mut self, t: Int):
        """Sends the time of day (Go `ViewTime`)."""
        var pk = SetTime()
        pk.time = Int32(t)
        self.queue[].push(pk)

    def view_time_cycle(mut self, do_day_light_cycle: Bool):
        """Starts or stops the client's day cycle (Go `ViewTimeCycle`)."""
        var pk = GameRulesChanged()
        pk.game_rules.append(
            GameRule(
                "dodaylightcycle",
                False,
                GameRuleValue(do_day_light_cycle),
            )
        )
        self.queue[].push(pk)

    def view_block_update(mut self, pos: Pos, rid: UInt32, layer: Int):
        """Sends a changed block (Go `ViewBlockUpdate`)."""
        var pk = UpdateBlock()
        pk.position = _block_pos(pos)
        pk.new_block_runtime_id = rid
        pk.flags = BLOCK_UPDATE_NETWORK
        pk.layer = UInt32(layer)
        self.queue[].push(pk)

    def view_entity[E: EntityTypes](mut self, e: EntityHandle[E]):
        """Shows a world entity (Go `ViewEntity`); only item entities are
        shown so far."""
        comptime if E == VanillaEntities:
            ref h = rebind[EntityHandle[VanillaEntities]](e)
            if not h.state.isa[ItemBehaviour]():
                return
            ref item = h.state[ItemBehaviour]
            var key = String(h.id)
            if key in self.queue[].entity_ids:
                return
            var id = self.queue[].new_entity_id(key)
            var pk = AddItemActor()
            pk.entity_unique_id = Int64(id)
            pk.entity_runtime_id = id
            var stack = item.item.copy()
            if not item.resolved():
                # Loaded from disk: only the NBT is known.
                stack = read_disk_nbt(
                    self.queue[].items[], item.item_nbt, item.item_nbt.root()
                )
            pk.item = instance_from_item(
                self.queue[].blocks[], self.queue[].items[], stack
            )
            pk.position = _vec32(h.data.pos)
            pk.velocity = _vec32(h.data.vel)
            var m = new_entity_metadata()
            try:
                m.set(ENTITY_DATA_KEY_WIDTH, Float32(0.25))
                m.set(ENTITY_DATA_KEY_HEIGHT, Float32(0.25))
                m.set(ENTITY_DATA_KEY_SCALE, Float32(1))
                m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_HAS_GRAVITY)
            except:
                pass
            pk.entity_metadata = m^
            self.queue[].push(pk)

    def hide_entity[E: EntityTypes](mut self, e: EntityHandle[E]):
        """Removes a world entity from view (Go `HideEntity`)."""
        var key = String(e.id)
        var found = self.queue[].entity_ids.get(key)
        if not found:
            return
        try:
            _ = self.queue[].entity_ids.pop(key)
        except:
            pass
        var pk = RemoveActor()
        pk.entity_unique_id = Int64(found.value())
        self.queue[].push(pk)

    def view_entity_movement[
        E: EntityTypes
    ](mut self, e: EntityHandle[E], pos: Vec3, rot: Rotation, on_ground: Bool):
        """Shows a world entity moving (Go `ViewEntityMovement`), with the
        item entity's network offset."""
        var found = self.queue[].entity_ids.get(String(e.id))
        if not found:
            return
        var pk = MoveActorAbsolute()
        pk.entity_runtime_id = found.value()
        pk.position = _vec32(pos.add(Vec3(0, ItemBehaviour.NETWORK_OFFSET, 0)))
        pk.rotation = _vec32(Vec3(rot.pitch(), rot.yaw(), rot.yaw()))
        if on_ground:
            pk.flags = MOVE_FLAG_ON_GROUND
        self.queue[].push(pk)

    def view_entity_velocity[
        E: EntityTypes
    ](mut self, e: EntityHandle[E], vel: Vec3):
        """Shows a world entity's velocity (Go `ViewEntityVelocity`)."""
        var found = self.queue[].entity_ids.get(String(e.id))
        if not found:
            return
        var pk = SetActorMotion()
        pk.entity_runtime_id = found.value()
        pk.velocity = _vec32(vel)
        self.queue[].push(pk)


def _block_pos(pos: Pos) -> BlockPos:
    var b = BlockPos()
    b.x = Int32(pos.x())
    b.y = Int32(pos.y())
    b.z = Int32(pos.z())
    return b


def _vec32(v: Vec3) -> ProtocolVec3:
    return ProtocolVec3(Float32(v.x()), Float32(v.y()), Float32(v.z()))
