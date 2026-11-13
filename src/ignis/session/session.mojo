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

from std.collections import Dict
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
from minecraft.protocol.block_pos import SubChunkPos as ProtocolSubChunkPos
from minecraft.protocol.command import COMMAND_PERMISSION_LEVEL_ANY
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
from minecraft.protocol.packet.chunk_radius_updated import ChunkRadiusUpdated
from minecraft.protocol.packet.id import (
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
from ..internal.mgl64 import Vec3, float_equal
from ..player.player import BBOX_HEIGHT, BBOX_WIDTH, EYE_HEIGHT, Player
from ..world.chunk.chunk import Chunk
from ..world.dimension import Dimension
from ..world.game_mode import GAME_MODE_SPECTATOR, GameMode
from ..world.generator import Generator
from ..world.loader import Loader, Viewer
from ..world.position import ChunkPos, SubChunkPos
from ..world.world import World, chunk_pos_from_block
from .chunk import (
    network_chunk,
    sub_chunk_entry_with_height_map,
    sub_chunk_index,
)
from .conn import Conn


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

    def __init__(out self):
        """Creates the settings Dragonfly's server uses by default."""
        self.max_chunk_radius = 32
        self.emote_chat_muted = False
        self.join_message = True
        self.quit_message = True


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

    def __init__(out self):
        """Creates a result in which nothing changed."""
        self.moved = False
        self.state_changed = False
        self.chat = None


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


def _block_pos(v: Vec3) -> BlockPos:
    var b = BlockPos()
    b.x = Int32(v.x)
    b.y = Int32(v.y)
    b.z = Int32(v.z)
    return b


struct Session[C: Conn](Movable, Viewer):
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
    var _loader: Optional[Loader]
    var _current_entity_runtime_id: UInt64
    var _entity_runtime_ids: Dict[String, UInt64]
    var _teleport_pos: Optional[Vec3]
    var _moving: Bool
    var _last_chunk_pos: ChunkPos
    var _dimension: Int32
    var _write_error: Optional[String]

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
        self._current_entity_runtime_id = 1
        self._entity_runtime_ids = Dict[String, UInt64]()
        self._teleport_pos = None
        self._moving = False
        self._last_chunk_pos = ChunkPos(0, 0)
        self._dimension = 0
        self._write_error = None
        self._entity_runtime_ids[
            uuid_key(self.player.uuid())
        ] = SELF_ENTITY_RUNTIME_ID
        if clamped:
            var pk = ChunkRadiusUpdated()
            pk.chunk_radius = self.chunk_radius
            self.write_packet(pk)
        self.send_speed(0.1)

    # ===------------------------------------------------------------------=== #
    # Writing
    # ===------------------------------------------------------------------=== #

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

    def flush(mut self):
        """Sends the queued packets as one batch."""
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

    def spawn[G: Generator & Copyable & Deinitable](mut self, mut w: World[G]):
        """Shows the player its world (Go `Spawn`): starts the chunk
        loader, the entity identifiers, the game mode and the player's own
        metadata.

        Parameters:
            G: The world's generator type.

        Args:
            w: The world the player spawns in.
        """
        var pos = self.player.position()
        self._dimension = Int32(w.dimension().id)
        self._loader = Loader(
            Int(self.chunk_radius), chunk_pos_from_block(pos.x, pos.z)
        )
        self._last_chunk_pos = chunk_pos_from_block(pos.x, pos.z)
        var pub = NetworkChunkPublisherUpdate()
        pub.position = _block_pos(pos)
        pub.radius = UInt32(self.chunk_radius) << 4
        self.write_packet(pub)
        self.send_available_entities()
        self.send_game_mode()
        self.view_entity_state(self.player.copy())

    def close(mut self):
        """Stops loading chunks (the world part of Go `close`)."""
        if self._loader:
            self._loader.value().close()

    def chunk_loader(ref self) -> ref[self._loader] Optional[Loader]:
        """Returns the chunk loader, set once the player spawned.

        Returns:
            The loader, or `None` before `spawn`.
        """
        return self._loader

    def send_chunks[
        G: Generator & Copyable & Deinitable
    ](mut self, mut w: World[G]):
        """Moves the chunk loader to the player and sends up to four new
        chunks (Go `sendChunks`, run every tick).

        Parameters:
            G: The world's generator type.

        Args:
            w: The world.
        """
        if not self._loader:
            return
        var pos = self.player.position()
        var loader = self._loader.take()
        loader.move(pos)
        # Go compares the block position shifted left by 4, which changes
        # whenever the block does; the publisher update follows blocks.
        var chunk_pos = ChunkPos(Int32(pos.x) << 4, Int32(pos.z) << 4)
        if chunk_pos != self._last_chunk_pos:
            self._last_chunk_pos = chunk_pos
            var pub = NetworkChunkPublisherUpdate()
            pub.position = _block_pos(pos)
            pub.radius = UInt32(self.chunk_radius) << 4
            self.write_packet(pub)
        loader.load(w, self, _CHUNKS_PER_TICK)
        self._loader = loader^

    def view_chunk(mut self, pos: ChunkPos, dim: Dimension, mut c: Chunk):
        """Sends a chunk's biomes; the client then requests its sub-chunks
        (Go `ViewChunk` and `sendNetworkChunk`).

        Args:
            pos: The position of the chunk.
            dim: The dimension of the chunk.
            c: The chunk.
        """
        var pk = network_chunk(pos, Int32(dim.id), c)
        self.write_packet(pk)

    def view_sub_chunks[
        G: Generator & Copyable & Deinitable
    ](
        mut self,
        centre: SubChunkPos,
        offsets: List[SubChunkOffset],
        mut w: World[G],
    ):
        """Answers a sub-chunk request (Go `ViewSubChunks`).

        Parameters:
            G: The world's generator type.

        Args:
            centre: The centre of the request.
            offsets: The requested offsets from the centre.
            w: The world.
        """
        var r = w.range()
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
            if self._loader:
                loaded = self._loader.value().chunk_loaded(col_pos)
            if not loaded:
                var e = SubChunkEntry()
                e.result = SUB_CHUNK_RESULT_CHUNK_NOT_FOUND
                e.offset = offset
                pk.sub_chunk_entries.append(e^)
                continue
            var chunk_map = w.height_map(col_pos)
            pk.sub_chunk_entries.append(
                sub_chunk_entry_with_height_map(
                    offset, ind.value(), w.chunk(col_pos), chunk_map
                )
            )
        self.write_packet(pk)

    # ===------------------------------------------------------------------=== #
    # Packets from the client
    # ===------------------------------------------------------------------=== #

    def handle_packet[
        G: Generator & Copyable & Deinitable
    ](mut self, pk: PacketData, mut w: World[G]) raises -> HandleResult:
        """Handles one packet from the client (Go `handlePacket`). Packets
        without a ported handler are ignored, as Go ignores unhandled IDs.

        Parameters:
            G: The world's generator type.

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
            if self._loader:
                self._loader.value().change_radius(Int(radius))
            var upd = ChunkRadiusUpdated()
            upd.chunk_radius = radius
            self.write_packet(upd)
            return HandleResult()
        return HandleResult()

    def _handle_player_auth_input(
        mut self, var pk: PlayerAuthInput
    ) raises -> HandleResult:
        """Go `PlayerAuthInputHandler.Handle`: movement and input flags."""
        var res = HandleResult()
        res.moved = self._handle_movement(pk)
        res.state_changed = self._handle_input_flags(pk)
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
            pk.position.x = Float32(pos.x)
        if _bad(pk.position.y):
            pk.position.y = Float32(pos.y + EYE_HEIGHT)
        if _bad(pk.position.z):
            pk.position.z = Float32(pos.z)

        pk.position.y = pk.position.y - Float32(EYE_HEIGHT)
        var new_pos = Vec3.from_protocol(pk.position)
        var delta_pos = new_pos - pos
        var delta_yaw = Float64(pk.yaw) - rot.yaw()
        var delta_pitch = Float64(pk.pitch) - rot.pitch()

        if (
            not float_equal(delta_pos.len(), 0)
            or not float_equal(delta_yaw, 0)
            or not float_equal(delta_pitch, 0)
        ):
            if case .Some(expected) = self._teleport_pos:
                if (new_pos - expected).len() > 1:
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
        return self._entity_runtime_ids.get(uuid_key(p.uuid()))

    def _runtime_id_for(mut self, p: Player) -> UInt64:
        var key = uuid_key(p.uuid())
        var known = self._entity_runtime_ids.get(key)
        if case .Some(id) = known:
            return id
        self._current_entity_runtime_id += 1
        var id = self._current_entity_runtime_id
        self._entity_runtime_ids[key] = id
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
        if key in self._entity_runtime_ids:
            try:
                _ = self._entity_runtime_ids.pop(key)
            except:
                pass
        var entry = PlayerListEntry()
        entry.action_type = PLAYER_LIST_ACTION_REMOVE
        entry.uuid = p.uuid()
        var pk = PlayerList()
        pk.entries.append(entry^)
        self.write_packet(pk)

    def view_entity(mut self, p: Player):
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
        pk.position = p.position().to_protocol()
        pk.uuid = p.uuid()
        pk.username = p.name()
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
        pk.position = (pos + Vec3(0, EYE_HEIGHT, 0)).to_protocol()
        pk.rotation = Vec3(rot.pitch(), rot.yaw(), rot.yaw()).to_protocol()
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
        pk.position = (position + Vec3(0, EYE_HEIGHT, 0)).to_protocol()
        pk.pitch = Float32(rot.pitch())
        pk.yaw = Float32(rot.yaw())
        pk.head_yaw = Float32(rot.yaw())
        pk.mode = MOVE_MODE_TELEPORT
        var data = TeleportData()
        data.teleport_cause = TELEPORT_CAUSE_UNKNOWN
        pk.teleport_data = data^
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


def _bad(v: Float32) -> Bool:
    return isnan(v) or isinf(v)
