"""Player sessions, ported from Dragonfly `server/session/session.go`, the
handlers the first playable server needs (`handler_player_auth_input.go`,
`handler_text.go`, `handler_sub_chunk_request.go`,
`handler_request_chunk_radius.go`), the chunk and entity parts of
`world.go`, `chunk.go` and `player.go`, the player list of
`session_list.go`, and `entity_metadata.go` for players.

Differences from Go, all from the single-threaded design:

- The session holds its `Player` (Go's `Controllable` behind an entity
  handle) and is stepped by the server's loop: `handle_packet` replaces the
  `handlePackets` goroutine, and the server calls `send_chunks` once per
  tick in place of the `background` goroutine.
- The world owns the session's chunk loader and its viewer
  (`session.viewer.SessionViewer`), which queues what the world shows into
  a `PacketQueue` the session shares; the session writes the queue in order
  with its own packets. Players are not world entities yet, so the server
  shows them to each other directly.
- Go's player reaches its viewers through the world; here `handle_packet`
  reports what changed (`HandleResult`) and the server, which owns every
  session, calls the `view_*` methods of the others.
- Entities shown to the session are identified by the UUID of the player
  (Go keys them by entity handle).
- No client blob cache: chunks are always sent in full, which every client
  accepts.

Fixed Dragonfly bug: when a `PlayerAuthInput` carries a NaN or infinite
Y, Go substitutes the feet position and then subtracts the eye height,
moving the player 1.62 blocks down; Ignis substitutes the eye position.
"""

from std.collections import Dict, Set
from std.memory import ArcPointer
from std.math import isinf, isnan

from minecraft.nbt.encode import encode as encode_nbt
from minecraft.nbt.nbt import NETWORK_LITTLE_ENDIAN, TAG_COMPOUND
from minecraft.nbt.tree import Tree
from minecraft.protocol.ability import (
    ABILITY_ATTACK_MOBS,
    ABILITY_ATTACK_PLAYERS,
    ABILITY_BASE_WALK_SPEED,
    ABILITY_BUILD,
    ABILITY_COUNT,
    ABILITY_DOORS_AND_SWITCHES,
    ABILITY_FLYING,
    ABILITY_INSTANT_BUILD,
    ABILITY_INVULNERABLE,
    ABILITY_LAYER_TYPE_BASE,
    ABILITY_MAY_FLY,
    ABILITY_MINE,
    ABILITY_NO_CLIP,
    ABILITY_OPEN_CONTAINERS,
    AbilityData,
    AbilityLayer,
)
from minecraft.protocol.attribute import Attribute
from minecraft.protocol.block_pos import BlockPos
from minecraft.protocol.math import Vec3 as ProtocolVec3
from minecraft.protocol.block_pos import SubChunkPos as ProtocolSubChunkPos
from minecraft.protocol.command import (
    COMMAND_PERMISSION_LEVEL_ANY,
    CommandOrigin,
)
from minecraft.protocol.entity_metadata import (
    ENTITY_DATA_FLAG_ALWAYS_SHOW_NAME,
    ENTITY_DATA_FLAG_BREATHING,
    ENTITY_DATA_FLAG_CLIMB,
    ENTITY_DATA_FLAG_HAS_COLLISION,
    ENTITY_DATA_FLAG_HAS_GRAVITY,
    ENTITY_DATA_FLAG_SHOW_NAME,
    ENTITY_DATA_FLAG_SNEAKING,
    ENTITY_DATA_FLAG_SPRINTING,
    ENTITY_DATA_KEY_AIR_SUPPLY,
    ENTITY_DATA_KEY_AIR_SUPPLY_MAX,
    ENTITY_DATA_KEY_ALWAYS_SHOW_NAME_TAG,
    ENTITY_DATA_KEY_COLOR_INDEX,
    ENTITY_DATA_KEY_EFFECT_AMBIENCE,
    ENTITY_DATA_KEY_EFFECT_COLOR,
    ENTITY_DATA_KEY_FLAGS,
    ENTITY_DATA_KEY_HEIGHT,
    ENTITY_DATA_KEY_NAME,
    ENTITY_DATA_KEY_SCALE,
    ENTITY_DATA_KEY_WIDTH,
    EntityMetadata,
    new_entity_metadata,
)
from minecraft.protocol.os import DEVICE_UNKNOWN
from minecraft.protocol.packet.add_player import AddPlayer
from minecraft.protocol.packet.adventure_settings import (
    PERMISSION_LEVEL_MEMBER,
)
from minecraft.protocol.packet.available_actor_identifiers import (
    AvailableActorIdentifiers,
)
from minecraft.protocol.packet.biome_definition_list import (
    BiomeDefinitionList,
)
from minecraft.protocol.packet.chunk_radius_updated import ChunkRadiusUpdated
from minecraft.protocol.packet.command_request import CommandRequest
from minecraft.protocol.packet.item_stack_request import ItemStackRequest
from minecraft.protocol.packet.mob_equipment import MobEquipment
from minecraft.protocol.packet.take_item_actor import TakeItemActor
from minecraft.protocol.packet.animate import ANIMATE_ACTION_SWING_ARM, Animate
from minecraft.protocol.packet.level_event import LevelEvent
from minecraft.protocol.packet.level_sound_event import LevelSoundEvent
from minecraft.protocol.packet.update_block import (
    BLOCK_UPDATE_NETWORK,
    UpdateBlock,
)
from minecraft.protocol.packet.player_auth_input import (
    INPUT_FLAG_PERFORM_BLOCK_ACTIONS,
    INPUT_FLAG_PERFORM_ITEM_INTERACTION,
    INPUT_FLAG_PERFORM_ITEM_STACK_REQUEST,
)
from minecraft.protocol.container import CONTAINER_INVENTORY, CONTAINER_OFFHAND
from minecraft.protocol.item import ItemInstance
from minecraft.protocol.inventory import (
    INVENTORY_ACTION_SOURCE_CONTAINER,
    INVENTORY_ACTION_SOURCE_WORLD,
    USE_ITEM_ACTION_BREAK_BLOCK,
    USE_ITEM_ACTION_CLICK_AIR,
    USE_ITEM_ACTION_CLICK_BLOCK,
    MismatchTransactionData,
    NormalTransactionData,
    ReleaseItemTransactionData,
    UseItemOnEntityTransactionData,
    UseItemTransactionData,
)
from minecraft.protocol.packet.inventory_transaction import (
    InventoryTransaction,
)
from minecraft.protocol.player import (
    PLAYER_ACTION_ABORT_BREAK,
    PLAYER_ACTION_CONTINUE_DESTROY_BLOCK,
    PLAYER_ACTION_CRACK_BREAK,
    PLAYER_ACTION_CREATIVE_PLAYER_DESTROY_BLOCK,
    PLAYER_ACTION_DIMENSION_CHANGE_DONE,
    PLAYER_ACTION_INTERACT_WITH_BLOCK,
    PLAYER_ACTION_MISSED_SWING,
    PLAYER_ACTION_PREDICT_DESTROY_BLOCK,
    PLAYER_ACTION_RESPAWN,
    PLAYER_ACTION_START_BREAK,
    PLAYER_ACTION_START_ITEM_USE_ON,
    PLAYER_ACTION_START_SLEEPING,
    PLAYER_ACTION_STOP_BREAK,
    PLAYER_ACTION_STOP_ITEM_USE_ON,
    PLAYER_ACTION_STOP_SLEEPING,
)
from ..block.cube.pos import Pos
from minecraft.protocol.inventory import WINDOW_ID_INVENTORY, WINDOW_ID_OFF_HAND
from minecraft.protocol.packet.update_player_game_type import (
    UpdatePlayerGameType,
)
from minecraft.protocol.packet.update_soft_enum import (
    SOFT_ENUM_ACTION_SET,
    UpdateSoftEnum,
)
from minecraft.protocol.packet.id import (
    ID_COMMAND_REQUEST,
    ID_INVENTORY_TRANSACTION,
    ID_ITEM_STACK_REQUEST,
    ID_MOB_EQUIPMENT,
    ID_PLAYER_AUTH_INPUT,
    ID_REQUEST_CHUNK_RADIUS,
    ID_SUB_CHUNK_REQUEST,
    ID_TEXT,
)
from minecraft.protocol.packet.move_actor_absolute import (
    MOVE_FLAG_ON_GROUND,
    MOVE_FLAG_TELEPORT,
    MoveActorAbsolute,
)
from minecraft.protocol.packet.move_player import (
    MOVE_MODE_TELEPORT,
    TELEPORT_CAUSE_UNKNOWN,
    MovePlayer,
)
from minecraft.protocol.packet.network_chunk_publisher_update import (
    NetworkChunkPublisherUpdate,
)
from minecraft.protocol.packet.packet import Packet, PacketData, encode_packet
from minecraft.protocol.packet.player_auth_input import (
    INPUT_FLAG_SNEAKING,
    INPUT_FLAG_START_FLYING,
    INPUT_FLAG_START_SPRINTING,
    INPUT_FLAG_STOP_FLYING,
    INPUT_FLAG_STOP_SPRINTING,
    PlayerAuthInput,
)
from minecraft.protocol.packet.player_list import PlayerList
from minecraft.protocol.packet.remove_actor import RemoveActor
from minecraft.protocol.packet.request_chunk_radius import RequestChunkRadius
from minecraft.protocol.packet.set_actor_data import SetActorData
from minecraft.protocol.packet.set_actor_motion import SetActorMotion
from minecraft.protocol.packet.set_player_game_type import (
    GAME_TYPE_CREATIVE,
    GAME_TYPE_SPECTATOR,
    GAME_TYPE_SURVIVAL,
    SetPlayerGameType,
)
from minecraft.protocol.packet.set_time import SetTime
from minecraft.protocol.packet.sub_chunk import SubChunk
from minecraft.protocol.packet.sub_chunk_request import SubChunkRequest
from minecraft.protocol.packet.text import (
    TEXT_TYPE_CHAT,
    TEXT_TYPE_RAW,
    TEXT_TYPE_TRANSLATION,
    Text,
)
from minecraft.protocol.packet.update_abilities import UpdateAbilities
from minecraft.protocol.packet.update_attributes import UpdateAttributes
from minecraft.protocol.player import (
    PLAYER_LIST_ACTION_ADD,
    PLAYER_LIST_ACTION_REMOVE,
    PlayerListEntry,
    TeleportData,
)
from minecraft.protocol.skin import Skin
from minecraft.protocol.sub_chunk import (
    SUB_CHUNK_RESULT_CHUNK_NOT_FOUND,
    SUB_CHUNK_RESULT_INDEX_OUT_OF_BOUNDS,
    SubChunkEntry,
    SubChunkOffset,
)
from minecraft.protocol.uuid import UUID

from ..block.cube.rotation import Rotation
from ..cmd.command import Command, ParamKind
from ..cmd.output import Output
from ..cmd.source import Source
from ..mgl64 import Vec3, float_equal
from ..player.player import BBOX_HEIGHT, BBOX_WIDTH, EYE_HEIGHT, Player
from ..world.biome import BiomeRegistry
from ..world.biome_definition import biome_definitions
from ..world.game_mode import GAME_MODE_SPECTATOR, GameMode
from ..world.loader import LoaderID
from ..world.position import ChunkPos, SubChunkPos
from ..world.world import World, WorldTypes
from .chunk import sub_chunk_entry, sub_chunk_index
from .command import build_available_commands, command_output
from .handler_item_stack_request import ItemStackRequestHandler
from .inventory import (
    INV_ARMOUR,
    INV_ENDER_CHEST,
    INV_MAIN,
    INV_OFF_HAND,
    INV_UI,
    Inventories,
    instance_from_item,
    inventory_content,
    inventory_slot,
    window_id,
)
from .item import stack_to_item
from ..item.stack import Stack
from ..world.block_registry import BasicBlockRegistry
from ..world.item import ItemRegistry
from nethernet.os.time import monotonic_ms
from .conn import Conn
from .viewer import PacketQueue


comptime SELF_ENTITY_RUNTIME_ID: UInt64 = 1
"""The entity runtime and unique ID of the session's own player (Go
`selfEntityRuntimeID`)."""
comptime _MAX_FLOAT32: Float32 = 3.4028234663852886e38
comptime _CHUNKS_PER_TICK = 4
"""How many chunks `send_chunks` loads per tick (Go's `toLoad` cap)."""


struct Config(Copyable, Defaultable):
    """Session settings (Go `session.Config`)."""

    var max_chunk_radius: Int
    """The largest chunk radius a client may use (Go `MaxChunkRadius`)."""
    var emote_chat_muted: Bool
    """Whether emote chat is muted (Go `EmoteChatMuted`)."""
    var join_message: Bool
    """Whether to broadcast vanilla's join message (Go's `JoinMessage`
    being `chat.MessageJoin` rather than zero)."""
    var quit_message: Bool
    """Whether to broadcast vanilla's quit message (Go `QuitMessage`)."""
    var biome_definitions: List[UInt8]
    """The encoded `BiomeDefinitionList` packet sent first (Go
    `sendBiomes`), from `biome_definition_packet`; empty sends none."""
    var blocks: ArcPointer[BasicBlockRegistry]
    """The block registry, for block items (Go `BlockRegistry`)."""
    var items: ArcPointer[ItemRegistry]
    """The item registry stacks are encoded with."""
    var creative_items: ArcPointer[List[Stack]]
    """The creative inventory, in network ID order (Go `creative.Items`)."""

    var creative_content: List[UInt8]
    """The encoded `CreativeContent` packet sent next (Go
    `creativeContent`); empty sends none."""
    var crafting_data: List[UInt8]
    """The encoded `CraftingData` packet (Go `sendRecipes`); empty sends
    none."""
    var trim_data: List[UInt8]
    """The encoded `TrimData` packet (Go `sendArmourTrimData`); empty sends
    none."""

    def __init__(out self):
        """Creates the settings Dragonfly's server uses by default."""
        self.max_chunk_radius = 32
        self.emote_chat_muted = False
        self.join_message = True
        self.quit_message = True
        self.biome_definitions = List[UInt8]()
        self.blocks = ArcPointer(BasicBlockRegistry())
        self.items = ArcPointer(ItemRegistry())
        self.creative_items = ArcPointer(List[Stack]())

        self.creative_content = List[UInt8]()
        self.crafting_data = List[UInt8]()
        self.trim_data = List[UInt8]()


def biome_definition_packet(r: BiomeRegistry) raises -> List[UInt8]:
    """Encodes the `BiomeDefinitionList` sent on join (Go `sendBiomes`)."""
    var defs = biome_definitions(r)
    var pk = BiomeDefinitionList()
    pk.biome_definitions = defs[0].copy()
    pk.string_list = defs[1].copy()
    return encode_packet(pk)


@fieldwise_init
struct BlockAction(Copyable):
    """A block action of the client (Go's `handlePlayerAction` input):
    one of the `PLAYER_ACTION_*` breaking actions, or `BREAK_NOW` for a
    `UseItem` break."""

    var action: Int32
    """The action."""
    var pos: Pos
    """The block."""
    var face: Int
    """The clicked face."""


@fieldwise_init
struct UseOnBlock(Copyable):
    """The arguments of Go's `UseItemOnBlock`."""

    var pos: Pos
    """The clicked block."""
    var face: Int
    """The clicked face."""
    var click: Vec3
    """Where on the block it was clicked, 0 to 1 on each axis."""


comptime BREAK_NOW: Int32 = -1
"""Go `UseItemActionBreakBlock`: break the block at once (`BreakBlock`)."""


struct HandleResult(Copyable, Defaultable):
    """What handling a packet changed that other sessions must see. Go
    shows these through the world's viewers from inside the handler."""

    var moved: Bool
    """The player moved or turned (Go `ViewEntityMovement` to viewers)."""
    var state_changed: Bool
    """The player's metadata changed, such as sneaking (Go
    `ViewEntityState` to viewers)."""
    var chat: Optional[String]
    """A chat line to send to every player (Go `chat.Global`)."""
    var command: Optional[String]
    """A command line to run as the player (Go `ExecuteCommand`)."""
    var held_changed: Bool
    """The held items changed (Go `ViewEntityItems` to viewers)."""
    var dropped: List[Stack]
    """Stacks the player dropped (Go `Controllable.Drop`)."""
    var block_actions: List[BlockAction]
    """Breaking actions for the server to apply (Go `StartBreaking`,
    `AbortBreaking`, `FinishBreaking`, `BreakBlock`)."""
    var use_on_block: Optional[UseOnBlock]
    """An item used on a block (Go `UseItemOnBlock`)."""

    def __init__(out self):
        """Creates a result in which nothing changed."""
        self.moved = False
        self.state_changed = False
        self.chat = None
        self.command = None
        self.held_changed = False
        self.dropped = List[Stack]()
        self.block_actions = List[BlockAction]()
        self.use_on_block = None


def uuid_key(id: UUID) -> String:
    """Returns the key the session uses for an entity.

    Args:
        id: The entity's UUID.

    Returns:
        The UUID as text.
    """
    return String(id)


def game_type_from_mode(mode: GameMode) -> Int32:
    """Returns the network game type of a game mode (Go
    `gameTypeFromMode`): adventure is sent as survival, as Go does.

    Args:
        mode: The game mode.

    Returns:
        A `GAME_TYPE_*` value.
    """
    if mode == GAME_MODE_SPECTATOR:
        return GAME_TYPE_SPECTATOR
    if mode.allows_flying() and mode.creative_inventory():
        return GAME_TYPE_CREATIVE
    return GAME_TYPE_SURVIVAL


def player_metadata(p: Player) raises -> EntityMetadata:
    """Builds the metadata of a player (Go `parseEntityMetadata` and
    `addSpecificMetadata` for the player properties ported so far).

    Args:
        p: The player.

    Returns:
        The metadata.

    Raises:
        Never in practice; setting a flag raises only on a malformed map.
    """
    var m = new_entity_metadata()
    m.set(ENTITY_DATA_KEY_WIDTH, Float32(BBOX_WIDTH))
    m.set(ENTITY_DATA_KEY_HEIGHT, Float32(BBOX_HEIGHT))
    m.set(ENTITY_DATA_KEY_EFFECT_COLOR, Int32(0))
    m.set(ENTITY_DATA_KEY_EFFECT_AMBIENCE, UInt8(0))
    m.set(ENTITY_DATA_KEY_COLOR_INDEX, UInt8(0))
    m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_HAS_GRAVITY)
    m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_CLIMB)
    if p.sneaking():
        m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_SNEAKING)
    if p.sprinting():
        m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_SPRINTING)
    # breather: a player out of water has full air and is breathing.
    m.set(ENTITY_DATA_KEY_AIR_SUPPLY, Int16(300))
    m.set(ENTITY_DATA_KEY_AIR_SUPPLY_MAX, Int16(300))
    m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_BREATHING)
    if p.game_mode().has_collision():
        m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_HAS_COLLISION)
    m.set(ENTITY_DATA_KEY_SCALE, Float32(1))
    # writeNameTagMetadata: players always show their name tag.
    var name_tag = p.name_tag()
    var show = name_tag.byte_length() > 0
    m.set(ENTITY_DATA_KEY_NAME, name_tag^)
    m.set(ENTITY_DATA_KEY_ALWAYS_SHOW_NAME_TAG, UInt8(1 if show else 0))
    if show:
        m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_SHOW_NAME)
        m.set_flag(ENTITY_DATA_KEY_FLAGS, ENTITY_DATA_FLAG_ALWAYS_SHOW_NAME)
    return m^


def vec32_to64(v: ProtocolVec3) -> Vec3:
    """Widens a network vector (Go `vec32To64`).

    Args:
        v: The vector.

    Returns:
        The same vector in `Float64`.
    """
    return Vec3(Float64(v.x), Float64(v.y), Float64(v.z))


def vec64_to32(v: Vec3) -> ProtocolVec3:
    """Narrows a vector for the network (Go `vec64To32`).

    Args:
        v: The vector.

    Returns:
        The vector in `Float32`.
    """
    return ProtocolVec3(Float32(v.x()), Float32(v.y()), Float32(v.z()))


def _block_chunk_key(pos: Vec3) -> ChunkPos:
    """Go's `ChunkPos{int32(pos[0]) << 4, int32(pos[2]) << 4}`."""
    return ChunkPos(Int32(pos.x()) << 4, Int32(pos.z()) << 4)


def _block_pos(v: Vec3) -> BlockPos:
    var b = BlockPos()
    b.x = Int32(v.x())
    b.y = Int32(v.y())
    b.z = Int32(v.z())
    return b


struct Session[C: Conn](Movable):
    """A connected player: decodes its packets and writes what it sees (Go
    `session.Session`).

    Parameters:
        C: The connection type.
    """

    var conn: Self.C
    """The connection (Go `conn`)."""
    var player: Player
    """The player the session controls (Go's `Controllable`)."""
    var join_skin: Skin
    """The skin the player joined with, sent in player lists (Go
    `joinSkin`)."""
    var chunk_radius: Int32
    """The chunk radius in use (Go `chunkRadius`)."""
    var max_chunk_radius: Int32
    """The largest radius allowed (Go `maxChunkRadius`)."""
    var _conf: Config
    var _loader: Optional[LoaderID]
    var _queue: ArcPointer[PacketQueue]
    var _teleport_pos: Optional[Vec3]
    var _moving: Bool
    var _last_chunk_pos: ChunkPos
    var _dimension: Int32
    var _write_error: Optional[String]
    var _command_origin: CommandOrigin
    var _runnables: Dict[String, List[Int]]
    var _enum_values: Dict[String, List[String]]
    var _soft_enums: Set[String]
    var invs: Inventories
    """The player's inventories (Go's session inventory fields)."""
    var _stack_requests: ItemStackRequestHandler

    def __init__(
        out self,
        var conn: Self.C,
        var player: Player,
        var skin: Skin,
        conf: Config,
    ):
        """Creates the session of a spawned connection (Go `Config.New`
        followed by `SetHandle`).

        Args:
            conn: The connection, after the client spawned.
            player: The player the session controls.
            skin: The skin from the client data.
            conf: The session settings.
        """
        var r = conn.chunk_radius()
        var clamped = r > conf.max_chunk_radius
        if clamped:
            r = conf.max_chunk_radius
        self.conn = conn^
        self.player = player^
        self.join_skin = skin^
        self.chunk_radius = Int32(r)
        self.max_chunk_radius = Int32(conf.max_chunk_radius)
        self._conf = conf.copy()
        self._loader = None
        self._queue = ArcPointer(PacketQueue(conf.blocks, conf.items))
        self._teleport_pos = None
        self._moving = False
        self._last_chunk_pos = ChunkPos(0, 0)
        self._dimension = 0
        self._write_error = None
        self._command_origin = CommandOrigin()
        self._runnables = Dict[String, List[Int]]()
        self._enum_values = Dict[String, List[String]]()
        self._soft_enums = Set[String]()
        self.invs = Inventories()
        self._stack_requests = ItemStackRequestHandler()
        self._queue[].entity_ids[
            uuid_key(self.player.uuid())
        ] = SELF_ENTITY_RUNTIME_ID
        # Go: sendBiomes, CreativeContent, sendRecipes, sendArmourTrimData.
        self._write_encoded(conf.biome_definitions)
        self._write_encoded(conf.creative_content)
        self._write_encoded(conf.crafting_data)
        self._write_encoded(conf.trim_data)
        if clamped:
            var pk = ChunkRadiusUpdated()
            pk.chunk_radius = self.chunk_radius
            self.write_packet(pk)
        self.send_speed(0.1)

    # ===------------------------------------------------------------------=== #
    # Writing
    # ===------------------------------------------------------------------=== #

    def _write_encoded(mut self, data: List[UInt8]):
        """Writes an encoded packet unless it is empty."""
        if len(data) == 0:
            return
        try:
            self.conn.write(data.copy())
        except e:
            self._write_error = String(e)

    def write_packet[P: Packet](mut self, mut pk: P):
        """Queues a packet (Go `writePacket`). A failed write is kept for
        `write_error()` and later writes are dropped, as Go drops writes
        to a closed session.

        Parameters:
            P: The packet type.

        Args:
            pk: The packet.
        """
        if self._write_error:
            return
        try:
            self.conn.write(encode_packet(pk))
        except e:
            self._write_error = String(e)

    def queue(self) -> ArcPointer[PacketQueue]:
        """Returns the queue the session's world viewer writes into.

        Returns:
            A reference to the shared queue, for `SessionViewer`.
        """
        return self._queue

    def drain_queue(mut self):
        """Writes what the world viewer queued to the connection."""
        if len(self._queue[].packets) == 0:
            return
        var n = len(self._queue[].packets)
        for i in range(n):
            if self._write_error:
                break
            try:
                self.conn.write(self._queue[].packets[i].copy())
            except e:
                self._write_error = String(e)
        self._queue[].packets.clear()

    def flush(mut self):
        """Sends the queued packets, the viewer's included, as one batch."""
        self.drain_queue()
        if self._write_error:
            return
        try:
            self.conn.flush()
        except e:
            self._write_error = String(e)

    def write_error(self) -> Optional[String]:
        """Returns why writing failed, if it did.

        Returns:
            The first write error, or `None`.
        """
        return self._write_error.copy()

    # ===------------------------------------------------------------------=== #
    # Spawning and chunks
    # ===------------------------------------------------------------------=== #

    def spawn[T: WorldTypes](mut self, mut w: World[T], loader: LoaderID):
        """Shows the player its world (Go `Spawn`): starts the chunk
        loader, the entity identifiers, the game mode and the player's own
        metadata.

        Parameters:
            T: The world's types.

        Args:
            w: The world the player spawns in.
            loader: The loader the server added for the session, with a
                `SessionViewer` over `queue()` (Go `NewLoader`).
        """
        var pos = self.player.position()
        self._dimension = Int32(w.dimension().id)
        self._loader = loader
        w.move_loader(loader, pos)
        self._last_chunk_pos = _block_chunk_key(pos)
        var pub = NetworkChunkPublisherUpdate()
        pub.position = _block_pos(pos)
        pub.radius = UInt32(self.chunk_radius) << 4
        self.write_packet(pub)
        self.send_available_entities()
        self.send_game_mode()
        self.view_entity_state(self.player.copy())
        self.send_inventories()

    def close[T: WorldTypes](mut self, mut w: World[T]):
        """Stops loading chunks (the world part of Go `close`).

        Parameters:
            T: The world's types.

        Args:
            w: The world the session's loader is in.
        """
        if case .Some(id) = self._loader:
            _ = w.close_loader(id)
            self._loader = None
        self.drain_queue()

    def into_conn(deinit self) -> Self.C:
        """Ends the session and returns its connection, such as to keep
        polling it while it closes.

        Returns:
            The connection.
        """
        return self.conn^

    def loader(self) -> Optional[LoaderID]:
        """Returns the session's chunk loader, set once the player spawned.

        Returns:
            The loader, or `None` before `spawn`.
        """
        return self._loader

    def send_chunks[T: WorldTypes](mut self, mut w: World[T]):
        """Moves the chunk loader to the player and sends up to four new
        chunks (Go `sendChunks`, run every tick).

        Parameters:
            T: The world's types.

        Args:
            w: The world.
        """
        if not self._loader:
            return
        var id = self._loader.value()
        var pos = self.player.position()
        w.move_loader(id, pos)
        # Go compares the block position shifted left by 4, which changes
        # whenever the block does; the publisher update follows blocks.
        var chunk_pos = _block_chunk_key(pos)
        if chunk_pos != self._last_chunk_pos:
            self._last_chunk_pos = chunk_pos
            var pub = NetworkChunkPublisherUpdate()
            pub.position = _block_pos(pos)
            pub.radius = UInt32(self.chunk_radius) << 4
            self.write_packet(pub)
        w.load(id, _CHUNKS_PER_TICK)
        self.drain_queue()

    def view_sub_chunks[
        T: WorldTypes
    ](
        mut self,
        centre: SubChunkPos,
        offsets: List[SubChunkOffset],
        mut w: World[T],
    ):
        """Answers a sub-chunk request (Go `ViewSubChunks`).

        Parameters:
            T: The world's types.

        Args:
            centre: The centre of the request.
            offsets: The requested offsets from the centre.
            w: The world.
        """
        var r = w.range()
        var br = w.block_registry()
        var pk = SubChunk()
        pk.dimension = Int32(w.dimension().id)
        pk.position = ProtocolSubChunkPos()
        pk.position.x = centre.x()
        pk.position.y = centre.y()
        pk.position.z = centre.z()
        pk.cache_enabled = False
        for offset in offsets:
            var ind = sub_chunk_index(centre, offset, r)
            if not ind:
                var e = SubChunkEntry()
                e.result = SUB_CHUNK_RESULT_INDEX_OUT_OF_BOUNDS
                e.offset = offset
                pk.sub_chunk_entries.append(e^)
                continue
            var col_pos = ChunkPos(
                centre.x() + Int32(offset.x), centre.z() + Int32(offset.z)
            )
            var loaded = False
            if case .Some(id) = self._loader:
                loaded = w.loader_has_chunk(id, col_pos)
            if not loaded:
                var e = SubChunkEntry()
                e.result = SUB_CHUNK_RESULT_CHUNK_NOT_FOUND
                e.offset = offset
                pk.sub_chunk_entries.append(e^)
                continue
            pk.sub_chunk_entries.append(
                sub_chunk_entry(offset, ind.value(), w.chunk(col_pos), br[])
            )
        self.write_packet(pk)

    # ===------------------------------------------------------------------=== #
    # Packets from the client
    # ===------------------------------------------------------------------=== #

    def handle_packet[
        T: WorldTypes
    ](mut self, pk: PacketData, mut w: World[T]) raises -> HandleResult:
        """Handles one packet from the client (Go `handlePacket`). Packets
        without a ported handler are ignored, as Go ignores unhandled IDs.

        Parameters:
            T: The world's types.

        Args:
            pk: The packet.
            w: The world the player is in.

        Returns:
            What other sessions must be shown.

        Raises:
            If the packet is malformed or invalid in its context; Go closes
            the session then.
        """
        var id = pk.id()
        if id == ID_PLAYER_AUTH_INPUT:
            return self._handle_player_auth_input(pk.decode[PlayerAuthInput]())
        if id == ID_TEXT:
            return self._handle_text(pk.decode[Text]())
        if id == ID_ITEM_STACK_REQUEST:
            var res = HandleResult()
            var held = self.invs.held_item()
            var off = self.invs.off_hand_item()
            var resp = self._stack_requests.handle(
                pk.decode[ItemStackRequest](),
                self.invs,
                self.player.game_mode().creative_inventory(),
                self._conf.creative_items[],
                monotonic_ms(),
                res.dropped,
            )
            self.write_packet(resp)
            # Go's inTransaction: the response already told the client.
            self._discard_inventory_changes()
            res.held_changed = (
                held != self.invs.held_item()
                or off != self.invs.off_hand_item()
            )
            return res^
        if id == ID_INVENTORY_TRANSACTION:
            return self._handle_inventory_transaction(
                pk.decode[InventoryTransaction]()
            )
        if id == ID_MOB_EQUIPMENT:
            return self._handle_mob_equipment(pk.decode[MobEquipment]())
        if id == ID_COMMAND_REQUEST:
            # Go `CommandRequestHandler`: the origin is kept for the output.
            var req = pk.decode[CommandRequest]()
            if req.internal:
                raise Error(
                    "command request packet must never have the internal"
                    " field set to true"
                )
            self._command_origin = req.command_origin.copy()
            var res = HandleResult()
            res.command = req.command_line
            return res^
        if id == ID_SUB_CHUNK_REQUEST:
            var req = pk.decode[SubChunkRequest]()
            if req.dimension != Int32(w.dimension().id):
                # An outdated request from a previous dimension.
                var empty = SubChunk()
                empty.dimension = req.dimension
                empty.position = req.position
                self.write_packet(empty)
            else:
                self.view_sub_chunks(
                    SubChunkPos(req.position.x, req.position.y, req.position.z),
                    req.offsets,
                    w,
                )
            return HandleResult()
        if id == ID_REQUEST_CHUNK_RADIUS:
            var req = pk.decode[RequestChunkRadius]()
            var radius = req.chunk_radius
            if radius > self.max_chunk_radius:
                radius = self.max_chunk_radius
            self.chunk_radius = radius
            if case .Some(id) = self._loader:
                w.change_loader_radius(id, Int(radius))
            var upd = ChunkRadiusUpdated()
            upd.chunk_radius = radius
            self.write_packet(upd)
            return HandleResult()
        return HandleResult()

    def _handle_inventory_transaction(
        mut self, pk: InventoryTransaction
    ) raises -> HandleResult:
        """Go `InventoryTransactionHandler.Handle`."""
        if len(pk.legacy_set_item_slots) > 2:
            raise Error("too many slot sync requests in inventory transaction")
        var res = HandleResult()
        ref v = pk.transaction_data.value
        if v.isa[NormalTransactionData]():
            self.send_inventories()
            try:
                self._handle_drop_transaction(pk, res)
            except:
                pass  # Go only debugs a bad drop.
        elif v.isa[MismatchTransactionData]():
            self.send_inventories()
        elif v.isa[UseItemTransactionData]():
            ref data = v[UseItemTransactionData]
            res = self._verify_and_set_held_slot(
                Int(data.hot_bar_slot), data.held_item
            )
            # Go resends the inventories instead of confirming the use.
            self.send_inventories()
            var pos = _pos(data.block_position)
            if data.action_type == USE_ITEM_ACTION_BREAK_BLOCK:
                res.block_actions.append(BlockAction(BREAK_NOW, pos, 0))
            elif data.action_type == USE_ITEM_ACTION_CLICK_BLOCK:
                res.use_on_block = UseOnBlock(
                    pos, Int(data.block_face), vec32_to64(data.clicked_position)
                )
            elif data.action_type != USE_ITEM_ACTION_CLICK_AIR:
                raise Error(t"unhandled UseItem ActionType {data.action_type}")
        elif v.isa[UseItemOnEntityTransactionData]():
            # Attacking and using items on entities are not ported yet.
            self.send_inventories()
        elif v.isa[ReleaseItemTransactionData]():
            pass
        self._send_legacy_slots(pk)
        return res^

    def _send_legacy_slots(mut self, pk: InventoryTransaction):
        """Resends the slots the client asked for (Go's deferred
        `LegacySetItemSlots` loop)."""
        for ref slot in pk.legacy_set_item_slots:
            if slot.container_id == CONTAINER_OFFHAND:
                var c = inventory_content(
                    self._conf.blocks[],
                    self._conf.items[],
                    self.invs.off_hand,
                    window_id(INV_OFF_HAND),
                )
                self.write_packet(c)
            elif slot.container_id == CONTAINER_INVENTORY:
                for n in slot.slots:
                    var it = self._slot(INV_MAIN, Int(n))
                    var u = inventory_slot(
                        self._conf.blocks[],
                        self._conf.items[],
                        it,
                        Int(n),
                        window_id(INV_MAIN),
                    )
                    self.write_packet(u)

    def _handle_drop_transaction(
        mut self, pk: InventoryTransaction, mut res: HandleResult
    ) raises:
        """Go `handleNormalTransaction`: dropping items with the drop key."""
        if len(pk.actions) != 2:
            raise Error("expected two actions for dropping an item")
        var slot = 0
        var count = 0
        var expected = Stack()
        for ref a in pk.actions:
            if (
                a.source_type == INVENTORY_ACTION_SOURCE_WORLD
                and a.inventory_slot == 0
            ):
                count = Int(a.new_item.stack.count)
            elif (
                a.source_type == INVENTORY_ACTION_SOURCE_CONTAINER
                and a.window_id
                and a.window_id.value() == WINDOW_ID_INVENTORY
            ):
                expected = stack_to_item(
                    self._conf.blocks[], self._conf.items[], a.old_item.stack
                )
                slot = Int(a.inventory_slot)
            else:
                raise Error("unexpected action type in drop item transaction")
        var actual = self.invs.inv.item(slot)
        if count < 1 or count > actual.count() or expected != actual:
            raise Error("invalid drop transaction")
        var dropped = actual.grow(count - actual.count())
        res.dropped.append(dropped.copy())
        self.invs.inv.set_item(slot, actual.grow(-count))

    def _verify_and_set_held_slot(
        mut self, slot: Int, held: ItemInstance
    ) raises -> HandleResult:
        """Go `VerifyAndSetHeldSlot`."""
        if slot < 0 or slot > 8:
            raise Error(t"slot exceeds hotbar range 0-8: slot is {slot}")
        var expected = stack_to_item(
            self._conf.blocks[], self._conf.items[], held.stack
        )
        var actual = self.invs.inv.item(slot)
        if expected != actual:
            var fix = inventory_slot(
                self._conf.blocks[],
                self._conf.items[],
                actual,
                slot,
                window_id(INV_MAIN),
            )
            self.write_packet(fix)
        var res = HandleResult()
        res.held_changed = slot != self.invs.held_slot
        self.invs.held_slot = slot
        return res^

    def _handle_mob_equipment(
        mut self, pk: MobEquipment
    ) raises -> HandleResult:
        """Go `MobEquipmentHandler` and `VerifyAndSetHeldSlot`."""
        if pk.entity_runtime_id != SELF_ENTITY_RUNTIME_ID:
            raise Error("entity runtime ID must be the session's own")
        var res = HandleResult()
        if Int8(pk.window_id) == WINDOW_ID_OFF_HAND:
            return res^
        if Int8(pk.window_id) != WINDOW_ID_INVENTORY:
            raise Error(
                t"only main inventory should be involved in slot change, got"
                t" window ID {pk.window_id}"
            )
        var slot = Int(pk.inventory_slot)
        if slot < 0 or slot > 8:
            raise Error(t"slot exceeds hotbar range 0-8: slot is {slot}")
        var expected = stack_to_item(
            self._conf.blocks[], self._conf.items[], pk.new_item.stack
        )
        var actual = self.invs.inv.item(slot)
        if expected != actual:
            # Out of sync: tell the client what the slot holds.
            var fix = inventory_slot(
                self._conf.blocks[],
                self._conf.items[],
                actual,
                slot,
                window_id(INV_MAIN),
            )
            self.write_packet(fix)
        res.held_changed = slot != self.invs.held_slot
        self.invs.held_slot = slot
        return res^

    def _handle_player_auth_input(
        mut self, var pk: PlayerAuthInput
    ) raises -> HandleResult:
        """Go `PlayerAuthInputHandler.Handle`: movement and input flags."""
        var res = HandleResult()
        res.moved = self._handle_movement(pk)
        # Go handleActions: item interaction, block actions, input flags,
        # then the item stack request.
        if pk.input_data.load(INPUT_FLAG_PERFORM_ITEM_INTERACTION):
            if not pk.item_interaction_data:
                raise Error(
                    "item interaction flag set without item interaction data"
                )
            ref data = pk.item_interaction_data.value()
            var held = stack_to_item(
                self._conf.blocks[], self._conf.items[], data.held_item.stack
            )
            if held == self.invs.held_item():
                if data.action_type != USE_ITEM_ACTION_BREAK_BLOCK:
                    raise Error(
                        t"unhandled UseItem ActionType for PlayerAuthInput"
                        t" packet {data.action_type}"
                    )
                res.block_actions.append(
                    BlockAction(BREAK_NOW, _pos(data.block_position), 0)
                )
        if pk.input_data.load(INPUT_FLAG_PERFORM_BLOCK_ACTIONS):
            if not pk.block_actions:
                raise Error("block actions flag set without block actions")
            for ref a in pk.block_actions.value():
                _check_player_action(a.action)
                res.block_actions.append(
                    BlockAction(a.action, _pos(a.block_pos), Int(a.face))
                )
        res.state_changed = self._handle_input_flags(pk)
        if pk.input_data.load(INPUT_FLAG_PERFORM_ITEM_STACK_REQUEST):
            if not pk.item_stack_request:
                raise Error(
                    "item stack request flag set without item stack request"
                )
            var req = ItemStackRequest()
            req.requests.append(pk.item_stack_request.value().copy())
            var held = self.invs.held_item()
            var resp = self._stack_requests.handle(
                req,
                self.invs,
                self.player.game_mode().creative_inventory(),
                self._conf.creative_items[],
                monotonic_ms(),
                res.dropped,
            )
            self.write_packet(resp)
            self._discard_inventory_changes()
            res.held_changed = held != self.invs.held_item()
        return res^

    def _handle_movement(mut self, mut pk: PlayerAuthInput) -> Bool:
        """Go `handleMovement`."""
        var rot = self.player.rotation()
        var pos = self.player.position()
        if _bad(pk.pitch):
            pk.pitch = Float32(rot.pitch())
        if _bad(pk.yaw):
            pk.yaw = Float32(rot.yaw())
        if _bad(pk.head_yaw):
            pk.head_yaw = Float32(rot.yaw())
        if _bad(pk.position.x):
            pk.position.x = Float32(pos.x())
        if _bad(pk.position.y):
            pk.position.y = Float32(pos.y() + EYE_HEIGHT)
        if _bad(pk.position.z):
            pk.position.z = Float32(pos.z())

        pk.position.y = pk.position.y - Float32(EYE_HEIGHT)
        var new_pos = vec32_to64(pk.position)
        var delta_pos = new_pos.sub(pos)
        var delta_yaw = Float64(pk.yaw) - rot.yaw()
        var delta_pitch = Float64(pk.pitch) - rot.pitch()

        if (
            not float_equal(delta_pos.len(), 0)
            or not float_equal(delta_yaw, 0)
            or not float_equal(delta_pitch, 0)
        ):
            if case .Some(expected) = self._teleport_pos:
                if new_pos.sub(expected).len() > 1:
                    # Moved before the teleport arrived: ignore until the
                    # client catches up.
                    return False
                self._teleport_pos = None
        self._moving = True
        return self.player.move(delta_pos, delta_yaw, delta_pitch)

    def _handle_input_flags(mut self, pk: PlayerAuthInput) raises -> Bool:
        """Go `handleInputFlags` for sprinting, sneaking and flying.

        Returns:
            True if the metadata viewers see changed.
        """
        var changed = False
        ref flags = pk.input_data
        if flags.load(INPUT_FLAG_START_SPRINTING):
            changed = changed or not self.player.sprinting()
            self.player.set_sprinting(True)
        if flags.load(INPUT_FLAG_STOP_SPRINTING):
            changed = changed or self.player.sprinting()
            self.player.set_sprinting(False)
        var sneaking = flags.load(INPUT_FLAG_SNEAKING)
        if sneaking != self.player.sneaking():
            self.player.set_sneaking(sneaking)
            changed = True
        if flags.load(INPUT_FLAG_START_FLYING):
            if not self.player.game_mode().allows_flying():
                self.send_abilities()
            else:
                self.player.start_flying()
        if (
            flags.load(INPUT_FLAG_STOP_FLYING)
            and self.player.game_mode() != GAME_MODE_SPECTATOR
        ):
            self.player.stop_flying()
        return changed

    def _handle_text(mut self, pk: Text) raises -> HandleResult:
        """Go `TextHandler.Handle`."""
        if pk.text_type != TEXT_TYPE_CHAT:
            raise Error(
                t"TextType should always be Chat ({TEXT_TYPE_CHAT}), but got"
                t" {pk.text_type}"
            )
        if pk.source_name != self.player.name():
            raise Error("SourceName must be equal to DisplayName")
        if pk.xuid != self.player.xuid():
            raise Error("XUID must be equal to player's XUID")
        var res = HandleResult()
        res.chat = self.player.chat(pk.message)
        return res^

    # ===------------------------------------------------------------------=== #
    # Sending state of the session's own player
    # ===------------------------------------------------------------------=== #

    def send_speed(mut self, speed: Float64):
        """Sends the movement speed attribute (Go `SendSpeed`).

        Args:
            speed: The speed, 0.1 by default.
        """
        var a = Attribute()
        a.name = "minecraft:movement"
        a.value = Float32(speed)
        a.max = _MAX_FLOAT32
        a.default_max = _MAX_FLOAT32
        a.default = 0.1
        var pk = UpdateAttributes()
        pk.entity_runtime_id = SELF_ENTITY_RUNTIME_ID
        pk.attributes.append(a^)
        self.write_packet(pk)

    def send_game_mode(mut self):
        """Sends the player's game mode and abilities (Go
        `SendGameMode`)."""
        var pk = SetPlayerGameType()
        pk.game_type = game_type_from_mode(self.player.game_mode())
        self.write_packet(pk)
        self.send_abilities()

    def send_abilities(mut self):
        """Sends what the player may do in its game mode (Go
        `SendAbilities`)."""
        var mode = self.player.game_mode()
        var abilities = UInt32(0)
        if mode.allows_flying():
            abilities |= ABILITY_MAY_FLY
            if self.player.flying():
                abilities |= ABILITY_FLYING
        if not mode.has_collision():
            abilities |= ABILITY_NO_CLIP
            self.view_entity_teleport(
                self.player.copy(), self.player.position()
            )
            self.player.start_flying()
        if not mode.allows_taking_damage():
            abilities |= ABILITY_INVULNERABLE
        if mode.creative_inventory():
            abilities |= ABILITY_INSTANT_BUILD
        if mode.allows_editing():
            abilities |= ABILITY_BUILD | ABILITY_MINE
        if mode.allows_interaction():
            abilities |= (
                ABILITY_DOORS_AND_SWITCHES
                | ABILITY_OPEN_CONTAINERS
                | ABILITY_ATTACK_PLAYERS
                | ABILITY_ATTACK_MOBS
            )
        if mode == GAME_MODE_SPECTATOR:
            abilities = (
                ABILITY_BUILD
                | ABILITY_MINE
                | ABILITY_DOORS_AND_SWITCHES
                | ABILITY_OPEN_CONTAINERS
                | ABILITY_ATTACK_PLAYERS
                | ABILITY_ATTACK_MOBS
            )
        var layer = AbilityLayer()
        layer.type = ABILITY_LAYER_TYPE_BASE
        layer.abilities = ABILITY_COUNT - 1
        layer.values = abilities
        layer.fly_speed = Float32(self.player.flight_speed())
        layer.vertical_fly_speed = Float32(self.player.vertical_flight_speed())
        layer.walk_speed = ABILITY_BASE_WALK_SPEED
        var pk = UpdateAbilities()
        pk.ability_data.entity_unique_id = Int64(SELF_ENTITY_RUNTIME_ID)
        pk.ability_data.player_permissions = UInt8(PERMISSION_LEVEL_MEMBER)
        pk.ability_data.command_permissions = COMMAND_PERMISSION_LEVEL_ANY
        pk.ability_data.layers.append(layer^)
        self.write_packet(pk)

    def send_available_entities(mut self):
        """Sends the entity identifiers the world registers (Go
        `sendAvailableEntities`). Only `minecraft:player` is registered so
        far."""
        try:
            var tree = Tree(TAG_COMPOUND)
            var list = tree.put_list(tree.root(), "idlist", TAG_COMPOUND)
            var entry = tree.append_compound(list)
            _ = tree.put_string(entry, "id", "minecraft:player")
            var pk = AvailableActorIdentifiers()
            pk.serialised_entity_identifiers = encode_nbt(
                tree, NETWORK_LITTLE_ENDIAN
            )
            self.write_packet(pk)
        except e:
            self._write_error = String(e)

    def send_message(mut self, message: String):
        """Sends a raw chat message (Go `SendMessage`).

        Args:
            message: The message.
        """
        var pk = Text()
        pk.text_type = TEXT_TYPE_RAW
        pk.message = message.copy()
        self.write_packet(pk)

    def send_translation(mut self, key: String, var parameters: List[String]):
        """Sends a message the client translates (Go `SendTranslation`).

        Args:
            key: The resolved translation, such as
                `§e%multiplayer.player.joined§r`.
            parameters: Its parameters.
        """
        var pk = Text()
        pk.text_type = TEXT_TYPE_TRANSLATION
        pk.needs_translation = True
        pk.message = key.copy()
        pk.parameters = parameters^
        self.write_packet(pk)

    # ===------------------------------------------------------------------=== #
    # Commands (Go command.go)
    # ===------------------------------------------------------------------=== #

    def send_command_output(mut self, o: Output):
        """Shows a command's output, answering the last `CommandRequest` (Go
        `SendCommandOutput`)."""
        var pk = command_output(o, self._command_origin)
        self.write_packet(pk)

    def send_available_commands[
        S: Source
    ](mut self, commands: Dict[String, Command[S]], src: S):
        """Sends the commands the player may run and records them and their
        enum values for the resend checks (Go `sendAvailableCommands` and
        `enums`)."""
        var runnable = Dict[String, List[Int]]()
        var pk = build_available_commands(
            commands, src, self._soft_enums, runnable
        )
        self.write_packet(pk)
        self._runnables = runnable^
        self._enum_values = _enum_values(commands, src)

    def resend_commands[
        S: Source
    ](mut self, commands: Dict[String, Command[S]], src: S) -> Bool:
        """Resends the commands if the overloads the player may run changed
        (Go `resendCommands`); returns whether they were resent."""
        var now = Dict[String, List[Int]]()
        for ref e in commands.items():
            if e.value.name() != e.key:
                continue
            var run = e.value.runnables(src)
            if len(run) > 0:
                now[e.key] = run^
        var changed = len(now) != len(self._runnables)
        if not changed:
            for ref e in now.items():
                var before = self._runnables.get(e.key)
                if not before or before.value() != e.value:
                    changed = True
                    break
        if changed:
            self.send_available_commands(commands, src)
        return changed

    def resend_enums[
        S: Source
    ](mut self, commands: Dict[String, Command[S]], src: S):
        """Resends enums whose options changed: soft enums with
        `UpdateSoftEnum`, others by making them soft and resending the
        commands (Go `resendEnums`)."""
        var now = _enum_values(commands, src)
        var resend = False
        for ref e in now.items():
            var before = self._enum_values.get(e.key)
            if before and before.value() == e.value:
                continue
            self._enum_values[e.key] = e.value.copy()
            if e.key in self._soft_enums:
                var pk = UpdateSoftEnum()
                pk.enum_type = e.key
                pk.options = e.value.copy()
                pk.action_type = SOFT_ENUM_ACTION_SET
                self.write_packet(pk)
            else:
                self._soft_enums.add(e.key)
                resend = True
        if resend:
            self.send_available_commands(commands, src)

    # ===------------------------------------------------------------------=== #
    # Inventories (Go player.go)
    # ===------------------------------------------------------------------=== #

    def send_inventories(mut self):
        """Sends every inventory (Go's `sendInv` calls in `Spawn`)."""
        for kind in [INV_MAIN, INV_UI, INV_OFF_HAND, INV_ARMOUR]:
            var pk = inventory_content(
                self._conf.blocks[],
                self._conf.items[],
                self.invs.get(kind),
                window_id(kind),
            )
            self.write_packet(pk)
        self._discard_inventory_changes()

    def send_held_slot(mut self):
        """Sends the selected hotbar slot and its item (Go `SendHeldSlot`)."""
        var pk = MobEquipment()
        pk.entity_runtime_id = SELF_ENTITY_RUNTIME_ID
        pk.new_item = instance_from_item(
            self._conf.blocks[], self._conf.items[], self.invs.held_item()
        )
        pk.inventory_slot = UInt8(self.invs.held_slot)
        pk.hot_bar_slot = UInt8(self.invs.held_slot)
        self.write_packet(pk)

    def send_inventory_changes(mut self) -> Bool:
        """Sends the slots changed outside item stack requests, as Go's
        inventory slot functions do; returns whether a held item changed."""
        var held = False
        for slot in self.invs.inv.take_changes():
            if slot == self.invs.held_slot:
                held = True
            var pk = inventory_slot(
                self._conf.blocks[],
                self._conf.items[],
                self._slot(INV_MAIN, slot),
                slot,
                window_id(INV_MAIN),
            )
            self.write_packet(pk)
        for slot in self.invs.armour.inv.take_changes():
            var pk = inventory_slot(
                self._conf.blocks[],
                self._conf.items[],
                self._slot(INV_ARMOUR, slot),
                slot,
                window_id(INV_ARMOUR),
            )
            self.write_packet(pk)
        for kind in [INV_OFF_HAND, INV_UI]:
            if len(self.invs.get(kind).take_changes()) == 0:
                continue
            if kind == INV_OFF_HAND:
                held = True
            var pk = inventory_content(
                self._conf.blocks[],
                self._conf.items[],
                self.invs.get(kind),
                window_id(kind),
            )
            self.write_packet(pk)
        _ = self.invs.ender_chest.take_changes()
        return held

    def _slot(self, kind: Int, slot: Int) -> Stack:
        try:
            return self.invs.get(kind).item(slot)
        except:
            return Stack()

    def _discard_inventory_changes(mut self):
        for kind in [
            INV_MAIN,
            INV_UI,
            INV_OFF_HAND,
            INV_ARMOUR,
            INV_ENDER_CHEST,
        ]:
            _ = self.invs.get(kind).take_changes()

    def view_entity_items(mut self, p: Player, main: Stack, off: Stack):
        """Shows another player's held items (Go `ViewEntityItems`)."""
        var known = self.entity_runtime_id(p)
        if not known or known.value() == SELF_ENTITY_RUNTIME_ID:
            return
        var pk = MobEquipment()
        pk.entity_runtime_id = known.value()
        pk.new_item = instance_from_item(
            self._conf.blocks[], self._conf.items[], main
        )
        self.write_packet(pk)
        var pk2 = MobEquipment()
        pk2.entity_runtime_id = known.value()
        pk2.new_item = instance_from_item(
            self._conf.blocks[], self._conf.items[], off
        )
        pk2.window_id = UInt8(Int(WINDOW_ID_OFF_HAND))
        self.write_packet(pk2)

    def view_time(mut self, time: Int64):
        """Sends the time of day (Go `ViewTime`).

        Args:
            time: The time in ticks.
        """
        var pk = SetTime()
        pk.time = Int32(time)
        self.write_packet(pk)

    # ===------------------------------------------------------------------=== #
    # Viewing entities
    # ===------------------------------------------------------------------=== #

    def entity_runtime_id(self, p: Player) -> Optional[UInt64]:
        """Returns the runtime ID the session uses for a player (Go
        `entityRuntimeID`).

        Args:
            p: The player.

        Returns:
            The runtime ID, or `None` if the player was never shown.
        """
        return self._queue[].entity_ids.get(uuid_key(p.uuid()))

    def _runtime_id_for(mut self, p: Player) -> UInt64:
        var key = uuid_key(p.uuid())
        var known = self._queue[].entity_ids.get(key)
        if case .Some(id) = known:
            return id
        var id = self._queue[].new_entity_id(key)
        return id

    def send_session_to_self(mut self):
        """Adds the session's own player to its player list (Go
        `sessionList.sendSessionTo(s, s)`)."""
        self.add_to_player_list(self.player.copy(), self.join_skin.copy())

    def add_to_player_list(mut self, p: Player, var skin: Skin):
        """Assigns a player a runtime ID and adds it to the player list
        (Go `sessionList.sendSessionTo`).

        Args:
            p: The player of the other session (or this one).
            skin: That player's join skin.
        """
        var id = self._runtime_id_for(p)
        var entry = PlayerListEntry()
        entry.action_type = PLAYER_LIST_ACTION_ADD
        entry.uuid = p.uuid()
        entry.entity_unique_id = Int64(id)
        entry.username = p.name()
        entry.xuid = p.xuid()
        entry.build_platform = Int32(DEVICE_UNKNOWN)
        entry.skin = skin^
        var pk = PlayerList()
        pk.entries.append(entry^)
        self.write_packet(pk)

    def remove_from_player_list(mut self, p: Player):
        """Forgets a player's runtime ID and removes it from the player
        list (Go `sessionList.unsendSessionFrom`).

        Args:
            p: The player of the session that left.
        """
        var key = uuid_key(p.uuid())
        if key in self._queue[].entity_ids:
            try:
                _ = self._queue[].entity_ids.pop(key)
            except:
                pass
        var entry = PlayerListEntry()
        entry.action_type = PLAYER_LIST_ACTION_REMOVE
        entry.uuid = p.uuid()
        var pk = PlayerList()
        pk.entries.append(entry^)
        self.write_packet(pk)

    def view_entity(mut self, p: Player, held: Stack = Stack()):
        """Shows another player (Go `ViewEntity` for a `Controllable` that
        is an actual player); the session's own player gets its state.

        Args:
            p: The player to show.
        """
        var id = self._runtime_id_for(p)
        if id == SELF_ENTITY_RUNTIME_ID:
            self.view_entity_state(p)
            return
        var rot = p.rotation()
        var pk = AddPlayer()
        try:
            pk.entity_metadata = player_metadata(p)
        except:
            pass
        pk.entity_runtime_id = id
        pk.game_type = game_type_from_mode(p.game_mode())
        pk.head_yaw = Float32(rot.yaw())
        pk.pitch = Float32(rot.pitch())
        pk.position = vec64_to32(p.position())
        pk.uuid = p.uuid()
        pk.username = p.name()
        pk.held_item = instance_from_item(
            self._conf.blocks[], self._conf.items[], held
        )
        pk.yaw = Float32(rot.yaw())
        pk.build_platform = Int32(DEVICE_UNKNOWN)
        pk.ability_data.entity_unique_id = Int64(id)
        var layer = AbilityLayer()
        layer.type = ABILITY_LAYER_TYPE_BASE
        layer.abilities = ABILITY_COUNT - 1
        pk.ability_data.layers.append(layer^)
        self.write_packet(pk)

    def hide_entity(mut self, p: Player):
        """Removes another player from view (Go `HideEntity`). Players keep
        their runtime ID until they leave the player list, as in Go.

        Args:
            p: The player to hide.
        """
        var known = self.entity_runtime_id(p)
        if not known or known.value() == SELF_ENTITY_RUNTIME_ID:
            return
        var pk = RemoveActor()
        pk.entity_unique_id = Int64(known.value())
        self.write_packet(pk)

    def view_entity_movement(
        mut self, p: Player, pos: Vec3, rot: Rotation, on_ground: Bool
    ):
        """Shows a player moving (Go `ViewEntityMovement`).

        Args:
            p: The player that moved.
            pos: Its new position.
            rot: Its new rotation.
            on_ground: Whether it is on the ground.
        """
        var known = self.entity_runtime_id(p)
        if not known:
            return
        var id = known.value()
        if id == SELF_ENTITY_RUNTIME_ID and self._moving:
            return
        self._view_entity_absolute_movement(id, pos, rot, on_ground, False)

    def _view_entity_absolute_movement(
        mut self,
        id: UInt64,
        pos: Vec3,
        rot: Rotation,
        on_ground: Bool,
        authoritative: Bool,
    ):
        """Go `viewEntityAbsoluteMovement` with the player's network
        offset."""
        var flags = UInt8(0)
        if on_ground:
            flags |= MOVE_FLAG_ON_GROUND
        if authoritative:
            flags |= MOVE_FLAG_TELEPORT
        var pk = MoveActorAbsolute()
        pk.entity_runtime_id = id
        pk.position = vec64_to32(pos.add(Vec3(0, EYE_HEIGHT, 0)))
        pk.rotation = vec64_to32(Vec3(rot.pitch(), rot.yaw(), rot.yaw()))
        pk.flags = flags
        self.write_packet(pk)

    def view_entity_teleport(mut self, p: Player, position: Vec3):
        """Teleports a player in view (Go `ViewEntityTeleport` for a
        `Controllable`).

        Args:
            p: The player.
            position: Where it is teleported to.
        """
        var known = self.entity_runtime_id(p)
        if not known:
            return
        var id = known.value()
        var rot = p.rotation()
        if id == SELF_ENTITY_RUNTIME_ID:
            self._teleport_pos = position
        var motion = SetActorMotion()
        motion.entity_runtime_id = id
        self.write_packet(motion)
        var pk = MovePlayer()
        pk.entity_runtime_id = id
        pk.position = vec64_to32(position.add(Vec3(0, EYE_HEIGHT, 0)))
        pk.pitch = Float32(rot.pitch())
        pk.yaw = Float32(rot.yaw())
        pk.head_yaw = Float32(rot.yaw())
        pk.mode = MOVE_MODE_TELEPORT
        var data = TeleportData()
        data.teleport_cause = TELEPORT_CAUSE_UNKNOWN
        pk.teleport_data = data^
        self.write_packet(pk)

    def view_level_event(mut self, event: Int32, pos: Vec3, data: Int32):
        """Sends a level event, such as block cracking or particles (Go's
        `ViewBlockAction` and `ViewParticle` cases)."""
        var pk = LevelEvent()
        pk.event_type = event
        pk.position = vec64_to32(pos)
        pk.event_data = data
        self.write_packet(pk)

    def view_sound(mut self, sound: StaticString, pos: Vec3, extra: Int32):
        """Plays a sound (Go `playSound` for the block sounds)."""
        var pk = LevelSoundEvent()
        pk.sound_type = String(sound)
        pk.position = vec64_to32(pos)
        pk.extra_data = extra
        pk.entity_type = ":"
        self.write_packet(pk)

    def view_swing_arm(mut self, p: Player):
        """Shows a player swinging its arm (Go `ViewEntityAction` with
        `SwingArmAction`); the player's own client animates itself."""
        var known = self.entity_runtime_id(p)
        if not known or known.value() == SELF_ENTITY_RUNTIME_ID:
            return
        var pk = Animate()
        pk.action_type = ANIMATE_ACTION_SWING_ARM
        pk.entity_runtime_id = known.value()
        self.write_packet(pk)

    def view_block(mut self, pos: Pos, rid: UInt32):
        """Sends the block at a position (Go `ViewBlockUpdate`, as
        `resendNearbyBlock` uses it)."""
        var pk = UpdateBlock()
        pk.position = _block_pos_of(pos)
        pk.new_block_runtime_id = rid
        pk.flags = BLOCK_UPDATE_NETWORK
        self.write_packet(pk)

    def view_take_item(mut self, item: UUID, taker: Player):
        """Shows a player picking up an item entity (Go `ViewEntityAction`
        with `PickedUpAction`)."""
        var item_id = self._queue[].entity_ids.get(uuid_key(item))
        var taker_id = self.entity_runtime_id(taker)
        if not item_id or not taker_id:
            return
        var pk = TakeItemActor()
        pk.item_entity_runtime_id = item_id.value()
        pk.taker_entity_runtime_id = taker_id.value()
        self.write_packet(pk)

    def view_entity_game_mode(mut self, p: Player):
        """Shows another player's game mode (Go `ViewEntityGameMode`)."""
        var known = self.entity_runtime_id(p)
        if not known:
            return
        var pk = UpdatePlayerGameType()
        pk.game_type = game_type_from_mode(p.game_mode())
        pk.player_unique_id = Int64(known.value())
        self.write_packet(pk)

    def view_entity_state(mut self, p: Player):
        """Sends a player's metadata (Go `ViewEntityState`).

        Args:
            p: The player.
        """
        var known = self.entity_runtime_id(p)
        if not known:
            return
        var pk = SetActorData()
        pk.entity_runtime_id = known.value()
        try:
            pk.entity_metadata = player_metadata(p)
        except:
            pass
        self.write_packet(pk)


def _enum_values[
    S: Source
](commands: Dict[String, Command[S]], src: S) -> Dict[String, List[String]]:
    # Go `Session.enums`: the options of every enum the source can use.
    var out = Dict[String, List[String]]()
    for ref e in commands.items():
        if e.value.name() != e.key:
            continue
        for params in e.value.params(src):
            for ref info in params:
                if info.kind == ParamKind.ENUM:
                    out[info.type_name] = info.options.copy()
    return out^


def _pos(b: BlockPos) -> Pos:
    return Pos(Int(b.x), Int(b.y), Int(b.z))


def _block_pos_of(p: Pos) -> BlockPos:
    var b = BlockPos()
    b.x = Int32(p.x())
    b.y = Int32(p.y())
    b.z = Int32(p.z())
    return b


def _check_player_action(action: Int32) raises:
    # Go handlePlayerAction: the actions it accepts; others close the
    # session.
    if (
        action == PLAYER_ACTION_START_SLEEPING
        or action == PLAYER_ACTION_RESPAWN
        or action == PLAYER_ACTION_DIMENSION_CHANGE_DONE
        or action == PLAYER_ACTION_STOP_SLEEPING
        or action == PLAYER_ACTION_START_BREAK
        or action == PLAYER_ACTION_CONTINUE_DESTROY_BLOCK
        or action == PLAYER_ACTION_ABORT_BREAK
        or action == PLAYER_ACTION_PREDICT_DESTROY_BLOCK
        or action == PLAYER_ACTION_STOP_BREAK
        or action == PLAYER_ACTION_CRACK_BREAK
        or action == PLAYER_ACTION_START_ITEM_USE_ON
        or action == PLAYER_ACTION_STOP_ITEM_USE_ON
        or action == PLAYER_ACTION_INTERACT_WITH_BLOCK
        or action == PLAYER_ACTION_CREATIVE_PLAYER_DESTROY_BLOCK
        or action == PLAYER_ACTION_MISSED_SWING
    ):
        return
    raise Error(t"unhandled ActionType {action}")


def _bad(v: Float32) -> Bool:
    return isnan(v) or isinf(v)
