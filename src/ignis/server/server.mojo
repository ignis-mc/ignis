"""The server, ported from Dragonfly `server/server.go` and `listener.go`.

One loop drives everything (`docs/architecture.md`): `step` waits on the
listener's and every connection's descriptors until the next deadline,
advances NetherNet and accepts connections, handles each session's packets,
runs the world ticks that are due and flushes every session. Where Go's
player shows itself to the world's viewers, the server, which owns every
session, calls their `view_*` methods.

Simplifications for the first playable milestone, to be replaced as the
world runtime is ported:

- One overworld with a flat generator in memory (`MemoryProvider`); no
  player provider.
- Players are not world entities yet (they join the entity set with the
  player package), so the server shows them to each other directly, and
  every player sees every other player regardless of distance (Go shows
  the entities of the chunks a viewer has loaded).
"""

from std.memory import ArcPointer

from minecraft.conn import Conn as MinecraftConn
from minecraft.game_data import GameData
from minecraft.listener import DefaultKeySet, ListenConfig, Listener
from minecraft.nbt.decode import decode as decode_nbt
from minecraft.nbt.encode import to_nbt
from minecraft.nbt.nbt import (
    LITTLE_ENDIAN,
    NBT,
    NETWORK_LITTLE_ENDIAN,
    TAG_COMPOUND,
)
from minecraft.nbt.tree import Tree
from minecraft.protocol.block import BlockEntry
from minecraft.protocol.game_rule import GameRule, GameRuleValue
from minecraft.protocol.info import CURRENT_VERSION
from minecraft.protocol.item import ITEM_ENTRY_VERSION_LEGACY, ItemEntry
from minecraft.protocol.login.data import ClientData
from minecraft.protocol.packet.adventure_settings import (
    PERMISSION_LEVEL_MEMBER,
)
from minecraft.protocol.packet.set_player_game_type import GAME_TYPE_SPECTATOR
from minecraft.protocol.skin import (
    SKIN_ANIMATION_BODY_128X128,
    SKIN_ANIMATION_BODY_32X32,
    SKIN_ANIMATION_HEAD,
    Skin,
    SkinAnimation,
)
from minecraft.protocol.packet.packet import encode_packet
from minecraft.protocol.uuid import UUID
from minecraft.server_status_provider import ListenerStatusProvider
from nethernet.crypto.base64 import base64_decode
from nethernet.os.addr import SocketAddr
from nethernet.os.poll import PollSet
from nethernet.os.random import random_bytes
from nethernet.os.time import monotonic_ms

from ..block.bedrock import Bedrock
from ..block.dirt import Dirt
from ..block.grass import Grass
from ..block.register import vanilla_block_registry
from ..block.register import VanillaBlocks
from ..entity.register import VanillaEntities
from ..item.creative.creative import load_creative_items
from ..item.recipe.vanilla import load_vanilla_recipes
from ..item.register import vanilla_item_registry
from ..mgl64 import Vec3
from ..player.player import EYE_HEIGHT, Player
from ..session.armour_trim import trim_data
from ..session.conn import NetConn
from ..session.creative import creative_content
from ..session.recipes import crafting_data, random_recipe_ids
from ..session.session import Config as SessionConfig
from ..session.session import (
    HandleResult,
    Session,
    load_biome_definitions,
    vec64_to32,
)
from ..session.viewer import SessionViewer
from ..world.biome.plains import Plains
from ..world.block_registry import BasicBlockRegistry
from ..world.conf import Config as WorldConfig
from ..world.game_mode import GAME_MODE_SPECTATOR
from ..world.generator.flat import Flat
from ..world.handler import NopHandler
from ..world.provider import MemoryProvider
from ..world.world import TICK_MS, World, WorldTypes
from .conf import Config


comptime _JOIN_KEY = "§e%multiplayer.player.joined§r"
"""Go's `chat.MessageJoin` as `SendTranslation` resolves it."""
comptime _QUIT_KEY = "§e%multiplayer.player.left§r"
"""Go's `chat.MessageQuit` as `SendTranslation` resolves it."""
comptime _MAX_CATCH_UP_TICKS = 5
"""The most ticks run in one `step` when the loop falls behind."""


def item_entries(path: String) raises -> List[ItemEntry]:
    """Reads the StartGame item table from `vanilla_items.nbt` (Go
    `itemEntries` over the `vanillaItems` map it decodes in `init`). Go
    ranges over a map, so its order is random; this keeps the file's order.

    Args:
        path: The path of `vanilla_items.nbt`.

    Returns:
        One entry per item.

    Raises:
        If the file cannot be read or is malformed.
    """
    var data: List[UInt8]
    with open(path, "r") as f:
        data = f.read_bytes()
    var tree = decode_nbt(Span(data), NETWORK_LITTLE_ENDIAN)
    var out = List[ItemEntry]()
    for e in tree.children(tree.root()):
        var entry = ItemEntry()
        entry.name = tree.name(e)
        entry.runtime_id = Int16(tree.get_int(e, "runtime_id"))
        if tree.has(e, "component_based"):
            entry.component_based = tree.get_bool(e, "component_based")
        entry.version = ITEM_ENTRY_VERSION_LEGACY
        if tree.has(e, "version"):
            entry.version = tree.get_int(e, "version")
        if case .Some(d) = tree.get(e, "data"):
            var sub = Tree(TAG_COMPOUND)
            for c in tree.children(d):
                _ = sub.put_tree(sub.root(), tree.name(c), tree, c)
            entry.data = to_nbt(sub, NETWORK_LITTLE_ENDIAN)
        out.append(entry^)
    return out^


def data_driven_block_entries(path: String) raises -> List[BlockEntry]:
    """Reads the vanilla data-driven blocks for StartGame (Go
    `makeBlockEntries` over `world.DataDrivenBlocks()`, which decodes
    `data_driven_blocks.nbt`). The client needs them to complete its block
    palette: without them its sequential runtime IDs do not match the
    server's.

    Args:
        path: The path of `data_driven_blocks.nbt` (little-endian NBT,
            `{blocks: [{name, components}]}`).

    Returns:
        One entry per block, in the file's order.

    Raises:
        If the file cannot be read or is malformed.
    """
    var data: List[UInt8]
    with open(path, "r") as f:
        data = f.read_bytes()
    var tree = decode_nbt(Span(data), LITTLE_ENDIAN)
    var out = List[BlockEntry]()
    for b in tree.children(tree.get_list(tree.root(), "blocks")):
        var entry = BlockEntry()
        entry.name = tree.get_string(b, "name")
        var props = Tree(TAG_COMPOUND)
        for c in tree.children(tree.get_compound(b, "components")):
            _ = props.put_tree(props.root(), tree.name(c), tree, c)
        entry.properties = to_nbt(props, NETWORK_LITTLE_ENDIAN)
        out.append(entry^)
    return out^


def item_packets(
    br: BasicBlockRegistry, vanilla_items_path: String
) raises -> Tuple[List[UInt8], List[UInt8], List[UInt8]]:
    """Encodes the `CreativeContent`, `CraftingData` and `TrimData` packets
    every session gets on join. Go builds them per session, with new random
    recipe IDs each time; Ignis builds them once, so the recipe IDs are
    random per server start."""
    var reg = vanilla_item_registry(vanilla_items_path)
    var creative = load_creative_items(br, reg)
    var recipes = load_vanilla_recipes(br, reg)
    var ids = random_recipe_ids(len(recipes.recipes()))
    var creative_pk = creative_content(br, reg, creative)
    var crafting_pk = crafting_data(br, reg, recipes, ids)
    var trim_pk = trim_data()
    return (
        encode_packet(creative_pk),
        encode_packet(crafting_pk),
        encode_packet(trim_pk),
    )


def _random_uuid_string() raises -> String:
    return String(UUID.from_random(Span(random_bytes(16))))


def _b64(s: String) -> List[UInt8]:
    """Decodes base64 like Go's `base64.StdEncoding.DecodeString` whose
    error Dragonfly ignores: bad input gives no bytes."""
    try:
        return base64_decode(s)
    except:
        return List[UInt8]()


def parse_skin(data: ClientData) raises -> Skin:
    """Builds the network skin of a player from its client data (Go
    `Server.parseSkin` followed by `skinToProtocol`).

    Args:
        data: The client data from the login.

    Returns:
        The skin as Dragonfly sends it in player lists.

    Raises:
        If no random bytes are available for the skin and cape IDs.
    """
    var s = Skin()
    s.skin_id = _random_uuid_string()
    # Go decodes the resource patch into a ModelConfig and encodes it
    # again; the JSON is passed through unchanged here.
    s.skin_resource_patch = _b64(data.skin_resource_patch)
    s.skin_image_width = UInt32(data.skin_image_width)
    s.skin_image_height = UInt32(data.skin_image_height)
    s.skin_data = _b64(data.skin_data)
    s.cape_image_width = UInt32(data.cape_image_width)
    s.cape_image_height = UInt32(data.cape_image_height)
    s.cape_data = _b64(data.cape_data)
    s.skin_geometry = _b64(data.skin_geometry)
    if len(s.skin_geometry) == 0:
        s.skin_geometry = List[UInt8]("{}".as_bytes())
    s.persona_skin = data.persona_skin
    s.cape_id = _random_uuid_string()
    s.full_id = data.skin_id.copy()
    if s.full_id.byte_length() == 0:
        s.full_id = _random_uuid_string()
    for a in data.animated_image_data:
        var anim = SkinAnimation()
        anim.image_width = UInt32(a.image_width)
        anim.image_height = UInt32(a.image_height)
        anim.image_data = _b64(a.image)
        anim.frame_count = Float32(Int(a.frames))
        if a.type == 1:
            anim.animation_type = SKIN_ANIMATION_HEAD
        elif a.type == 2:
            anim.animation_type = SKIN_ANIMATION_BODY_32X32
        elif a.type == 3:
            anim.animation_type = SKIN_ANIMATION_BODY_128X128
        anim.expression_type = UInt32(a.animation_expression)
        s.animations.append(anim^)
    s.trusted = True
    s.override_appearance = True
    s.geometry_data_engine_version = List[UInt8](CURRENT_VERSION.as_bytes())
    return s^


struct ServerWorld(WorldTypes):
    """The world types of the server (what Go's `server.Config` sets with
    interface values)."""

    comptime Generator = Flat
    """Dragonfly's default flat generator."""
    comptime Provider = MemoryProvider
    """Worlds are kept in memory until the disk provider is ported."""
    comptime Viewer = SessionViewer
    """Loaders show the world to sessions."""
    comptime Handler = NopHandler
    """No world handler yet."""
    comptime Blocks = VanillaBlocks
    """Every ported block type."""
    comptime Entities = VanillaEntities
    """Every ported entity type."""


def flat_world(conf: Config, now_ms: Int) raises -> World[ServerWorld]:
    """Creates Dragonfly's default world: a flat plains world of grass, two
    dirt layers and bedrock (Go `Config.Generator`'s default), in memory.

    Args:
        conf: The server settings, for the world name and game mode.
        now_ms: The current monotonic time.

    Returns:
        The world.

    Raises:
        If `block_states.nbt` cannot be loaded.
    """
    var br = vanilla_block_registry(conf.block_states_path)
    var layers: List[UInt32] = [
        br.block_runtime_id(Grass()),
        br.block_runtime_id(Dirt()),
        br.block_runtime_id(Dirt()),
        br.block_runtime_id(Bedrock()),
    ]
    var wc = WorldConfig[ServerWorld](
        Flat(Plains(), layers^), MemoryProvider(), ArcPointer(br^)
    )
    var w = wc^.new(now_ms)
    w.settings().name = conf.world_name.copy()
    w.set_default_game_mode(conf.default_game_mode)
    return w^


struct Server(Movable):
    """A Minecraft server: one listener, one world and its sessions (Go
    `server.Server`)."""

    var conf: Config
    """The settings."""
    var listener: Listener[DefaultKeySet]
    """The NetherNet listener."""
    var world: World[ServerWorld]
    """The world every player joins."""
    var sessions: List[Session[NetConn]]
    """The sessions of spawned players."""
    var _items: List[ItemEntry]
    var _biomes: List[UInt8]
    var _creative: List[UInt8]
    var _crafting: List[UInt8]
    var _trim: List[UInt8]
    var _custom_blocks: List[BlockEntry]
    var _pending: List[MinecraftConn]
    var _closing: List[MinecraftConn]
    var _next_tick: Int

    def __init__(out self, var conf: Config) raises:
        """Loads the world data and starts listening (Go `Config.New` and
        `Listen`).

        Args:
            conf: The settings.

        Raises:
            If a resource cannot be loaded or the address cannot be bound.
        """
        var world = flat_world(conf, monotonic_ms())
        var items = item_entries(conf.vanilla_items_path)
        var biomes = load_biome_definitions(conf.biome_definitions_path)
        var item_pks = item_packets(
            world.block_registry()[], conf.vanilla_items_path
        )
        var blocks = data_driven_block_entries(conf.data_driven_blocks_path)
        var lc = ListenConfig()
        lc.authentication_disabled = conf.auth_disabled
        lc.maximum_players = conf.max_players
        lc.lan_discovery = conf.lan_discovery
        lc.status_provider = ListenerStatusProvider(conf.name, "Ignis")
        var listener = lc.listen(conf.address)
        self.conf = conf^
        self.listener = listener^
        self.world = world^
        self.sessions = List[Session[NetConn]]()
        self._items = items^
        self._biomes = biomes^
        self._creative = item_pks[0].copy()
        self._crafting = item_pks[1].copy()
        self._trim = item_pks[2].copy()
        self._custom_blocks = blocks^
        self._pending = List[MinecraftConn]()
        self._closing = List[MinecraftConn]()
        self._next_tick = monotonic_ms() + TICK_MS

    def addr(mut self) raises -> SocketAddr:
        """Returns the address the listener is bound to.

        Returns:
            The signaling address.

        Raises:
            If the socket was closed.
        """
        return self.listener.addr()

    def player_count(self) -> Int:
        """Counts the players online (Go `PlayerCount`).

        Returns:
            The number of spawned players.
        """
        return len(self.sessions)

    def run(mut self) raises:
        """Runs the loop forever (Go `Listen` and `Accept` combined).

        Raises:
            If the listener fails.
        """
        while True:
            self.step(50)

    def step(mut self, max_wait_ms: Int) raises:
        """Runs one iteration of the event loop.

        Args:
            max_wait_ms: The longest time to wait for network activity.

        Raises:
            If the listener fails.
        """
        var set = PollSet()
        self.listener.add_poll_fds(set)
        var due = min(self.listener.next_timeout(), self._next_tick)
        for _i in range(len(self._pending)):
            ref c = self._pending[_i]
            c.add_poll_fds(set)
            due = min(due, c.next_timeout())
        for _i in range(len(self._closing)):
            ref c = self._closing[_i]
            c.add_poll_fds(set)
            due = min(due, c.next_timeout())
        for _i in range(len(self.sessions)):
            ref s = self.sessions[_i]
            s.conn.conn.add_poll_fds(set)
            due = min(due, s.conn.conn.next_timeout())
        _ = set.wait(max(0, min(due - monotonic_ms(), max_wait_ms)))

        var now = monotonic_ms()
        self.listener.poll(now)
        for err in self.listener.take_errors():
            print("listener:", err)
        while True:
            var accepted = self.listener.try_accept()
            if not accepted:
                break
            self._finalise_conn(accepted.take())
        self._poll_pending(now)
        self._poll_closing(now)
        self._handle_sessions(now)

        if now >= self.world.next_deadline_ms():
            _ = self.world.tick(now)
        var ticks = 0
        while now >= self._next_tick and ticks < _MAX_CATCH_UP_TICKS:
            self._tick()
            self._next_tick += TICK_MS
            ticks += 1
        if now >= self._next_tick:
            # Too far behind: skip ticks rather than spiral.
            self._next_tick = now + TICK_MS

        for _i in range(len(self.sessions)):
            ref s = self.sessions[_i]
            s.flush()
        self._remove_closed_sessions()

    # ===------------------------------------------------------------------=== #
    # Joining
    # ===------------------------------------------------------------------=== #

    def default_game_data(self) -> GameData:
        """Returns the game data sent to a new player (Go
        `defaultGameData` and `finaliseConn`).

        Returns:
            The data for `start_game`.
        """
        var mode = self.world.default_game_mode()
        var data = GameData()
        data.entity_unique_id = 1
        data.entity_runtime_id = 1
        data.world_name = self.conf.name.copy()
        data.base_game_version = String(CURRENT_VERSION)
        data.time = Int64(self.world.time())
        data.difficulty = 2
        data.player_game_mode = Int32(mode.id)
        if mode == GAME_MODE_SPECTATOR:
            data.player_game_mode = GAME_TYPE_SPECTATOR
        data.player_permissions = UInt8(PERMISSION_LEVEL_MEMBER)
        data.player_position = vec64_to32(
            self._spawn_position().add(Vec3(0, EYE_HEIGHT, 0))
        )
        data.dimension = Int32(self.world.dimension().id)
        data.items = self._items.copy()
        data.custom_blocks = self._custom_blocks.copy()
        data.game_rules.append(
            GameRule("naturalregeneration", False, GameRuleValue(False))
        )
        data.game_rules.append(
            GameRule("locatorBar", False, GameRuleValue(False))
        )
        data.server_authoritative_inventory = True
        data.player_movement_settings.server_authoritative_block_breaking = True
        data.emote_chat_muted = self.conf.mute_emote_chat
        return data^

    def _spawn_position(self) -> Vec3:
        """Go `w.Spawn().Vec3Centre()`."""
        var s = self.world.spawn()
        return Vec3(
            Float64(s.x()) + 0.5, Float64(s.y()) + 0.5, Float64(s.z()) + 0.5
        )

    def _finalise_conn(mut self, var conn: MinecraftConn):
        """Starts spawning an accepted connection (Go `finaliseConn` up to
        `StartGameContext`)."""
        print(
            t"connection accepted name={conn.identity_data.display_name}"
            t" xuid={conn.identity_data.xuid}"
            t" authenticated={conn.authenticated()}"
        )
        try:
            conn.start_game(self.default_game_data())
        except e:
            print("start game:", e)
            conn.start_close()
            self._closing.append(conn^)
            self.listener.connection_closed()
            return
        self._pending.append(conn^)

    def _poll_pending(mut self, now: Int):
        var i = 0
        while i < len(self._pending):
            ref conn = self._pending[i]
            try:
                conn.poll(now)
            except e:
                print("spawn failed:", e)
            if conn.is_closed():
                print(
                    t"spawn failed name={conn.identity_data.display_name}:"
                    t" {conn.close_reason()}"
                )
                _ = self._pending.pop(i)
                self.listener.connection_closed()
                continue
            if conn.spawned():
                var c = self._pending.pop(i)
                self._create_player(c^)
                continue
            i += 1

    def _poll_closing(mut self, now: Int):
        var i = 0
        while i < len(self._closing):
            try:
                self._closing[i].poll(now)
            except:
                pass
            if self._closing[i].is_closed():
                _ = self._closing.pop(i)
                continue
            i += 1

    def _create_player(mut self, var conn: MinecraftConn):
        """Creates the session and player of a spawned connection and shows
        it to everyone (Go `finaliseConn` after `StartGameContext`,
        `createPlayer`, `SetHandle` and `Spawn`)."""
        var name = conn.identity_data.display_name.copy()
        var uuid: UUID
        try:
            uuid = UUID.parse(conn.identity_data.identity)
        except e:
            print(t"spawn failed name={name}: invalid identity: {e}")
            conn.disconnect("Invalid identity.")
            self._closing.append(conn^)
            self.listener.connection_closed()
            return
        for _i in range(len(self.sessions)):
            ref s = self.sessions[_i]
            if s.player.uuid() == uuid:
                print(t"spawn failed name={name}: already logged in")
                conn.disconnect("Already logged in.")
                self._closing.append(conn^)
                self.listener.connection_closed()
                return
        var skin: Skin
        try:
            skin = parse_skin(conn.client_data)
        except e:
            print(t"spawn failed name={name}: skin: {e}")
            conn.start_close()
            self._closing.append(conn^)
            self.listener.connection_closed()
            return
        var player = Player(
            name,
            conn.identity_data.xuid,
            uuid,
            self._spawn_position(),
            self.world.default_game_mode(),
        )
        player.set_locale(conn.client_data.language_code)
        var sc = SessionConfig()
        sc.max_chunk_radius = self.conf.max_chunk_radius
        sc.emote_chat_muted = self.conf.mute_emote_chat
        sc.join_message = self.conf.join_quit_messages
        sc.quit_message = self.conf.join_quit_messages
        sc.biome_definitions = self._biomes.copy()
        sc.creative_content = self._creative.copy()
        sc.crafting_data = self._crafting.copy()
        sc.trim_data = self._trim.copy()
        self.sessions.append(Session(NetConn(conn^), player^, skin^, sc))
        var n = len(self.sessions) - 1
        var me = self.sessions[n].player.copy()
        var my_skin = self.sessions[n].join_skin.copy()
        # sessionList.Add: everyone sees everyone in the player list.
        for j in range(n):
            self.sessions[j].add_to_player_list(me, my_skin.copy())
            var other = self.sessions[j].player.copy()
            var other_skin = self.sessions[j].join_skin.copy()
            self.sessions[n].add_to_player_list(other, other_skin^)
        self.sessions[n].send_session_to_self()
        var loader = self.world.add_loader(
            Int(self.sessions[n].chunk_radius),
            SessionViewer(self.sessions[n].queue()),
        )
        self.sessions[n].spawn(self.world, loader)
        # World.AddEntity: viewers see the new player and it sees them.
        for j in range(n):
            self.sessions[j].view_entity(me)
            var other = self.sessions[j].player.copy()
            self.sessions[n].view_entity(other)
        print(t"player joined name={name} uuid={uuid}")
        if self.conf.join_quit_messages:
            for _i in range(len(self.sessions)):
                ref s = self.sessions[_i]
                s.send_translation(String(_JOIN_KEY), [name.copy()])

    # ===------------------------------------------------------------------=== #
    # Sessions
    # ===------------------------------------------------------------------=== #

    def _handle_sessions(mut self, now: Int):
        for i in range(len(self.sessions)):
            try:
                self.sessions[i].conn.conn.poll(now)
            except e:
                print(t"session {self.sessions[i].player.name()}: {e}")
            while not self.sessions[i].conn.conn.is_closed():
                var next = self.sessions[i].conn.conn.try_read_packet()
                if not next:
                    break
                try:
                    var res = self.sessions[i].handle_packet(
                        next.value(), self.world
                    )
                    self._apply(i, res)
                except e:
                    # Go closes the connection when a handler fails.
                    print(
                        t"process packet {next.value().id()} of"
                        t" {self.sessions[i].player.name()}: {e}"
                    )
                    self.sessions[i].conn.conn.start_close()
                    break

    def _apply(mut self, i: Int, res: HandleResult):
        """Shows what a handled packet changed to the other sessions."""
        if res.moved or res.state_changed:
            var p = self.sessions[i].player.copy()
            var pos = p.position()
            var rot = p.rotation()
            for j in range(len(self.sessions)):
                if j == i:
                    continue
                if res.moved:
                    self.sessions[j].view_entity_movement(
                        p, pos, rot, p.on_ground()
                    )
                if res.state_changed:
                    self.sessions[j].view_entity_state(p)
        if case .Some(line) = res.chat:
            print(line)
            for _i in range(len(self.sessions)):
                ref s = self.sessions[_i]
                s.send_message(line)

    def _tick(mut self):
        """Runs the per-tick session work (each session's `background`
        loop in Go); the world ticks on its own deadline."""
        for _i in range(len(self.sessions)):
            ref s = self.sessions[_i]
            s.send_chunks(self.world)

    def _remove_closed_sessions(mut self):
        """Removes sessions whose connection closed (Go `Session.close`
        and `sessionList.Remove`)."""
        var i = 0
        while i < len(self.sessions):
            ref s = self.sessions[i]
            var closed = s.conn.conn.is_closed() or Bool(s.write_error())
            if not closed:
                i += 1
                continue
            var reason = s.conn.conn.close_reason()
            if s.write_error():
                reason = s.write_error().value()
            var gone = self.sessions.pop(i)
            gone.close(self.world)
            var p = gone.player.copy()
            for _i in range(len(self.sessions)):
                ref other = self.sessions[_i]
                other.hide_entity(p)
                other.remove_from_player_list(p)
            print(t"player left name={p.name()}: {reason}")
            if self.conf.join_quit_messages:
                for _i in range(len(self.sessions)):
                    ref other = self.sessions[_i]
                    other.send_translation(String(_QUIT_KEY), [p.name()])
            var c = gone^.into_conn()
            var inner = c^.into_inner()
            inner.start_close()
            self._closing.append(inner^)
            self.listener.connection_closed()
