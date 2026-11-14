"""The server, ported from Dragonfly `server/server.go` and `listener.go`.

One loop drives everything (`docs/architecture.md`): `step` waits on the
listener's and every connection's descriptors until the next deadline,
advances NetherNet and accepts connections, handles each session's packets,
runs the world ticks that are due and flushes every session. Where Go's
player shows itself to the world's viewers, the server, which owns every
session, calls their `view_*` methods.

The world is kept on disk in the vanilla format (`[World] SaveData`,
`Folder`) and player data in playerdb (`[Players] SaveData`, `Folder`), as
`UserConfig.Config` sets up Dragonfly's providers. Chunks that are not on
disk come from the flat generator. The world, the settings and the online
players are saved every `save_interval_ms`, when a player leaves (their
data) and on `close`, which SIGINT and SIGTERM trigger once
`close_on_program_end` was called.

Differences from Dragonfly:

- Only the overworld exists, and a player saved in another dimension
  joins it.
- A spawn at Y 32767 (vanilla's "find the surface" value, which new worlds
  get from `level.dat` defaults) is moved onto the highest block at its
  X and Z; Go would spawn the player at Y 32767.
- The periodic save also writes `level.dat` and the player data, so that a
  crash loses at most one interval; Go writes them only on close.
- The world's name and default game mode come from `config.toml` for a new
  world; an existing world keeps those in its `level.dat`.

Simplifications, to be replaced as the runtime is ported:

- Players are not world entities yet (they join the entity set with the
  player package), so the server shows them to each other directly, and
  every player sees every other player regardless of distance (Go shows
  the entities of the chunks a viewer has loaded).
"""

from std.collections import Dict
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

from ..internal.fs import exists, join
from ..internal.signal import (
    SIGINT,
    SIGTERM,
    SignalFD,
    block_in_every_thread,
)
from ..internal.stdin import STDIN, LineReader
from ..block.cube.pos import Pos
from ..block.cube.rotation import Rotation
from ..player.playerdb.json import Data as PlayerData
from ..player.playerdb.leveldb import Provider as PlayerProvider
from ..world.provider import uuid_key
from ..cmd.register import Registry
from .builtin import register_builtin_commands
from .command import CommandSource, execute_command
from .provider import WorldProvider

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
    biome_definition_packet,
    game_type_from_mode,
    vec64_to32,
)
from ..session.viewer import SessionViewer
from ..world.biome.plains import Plains
from ..world.biome.register import vanilla_biome_registry
from ..world.block_registry import BasicBlockRegistry
from ..world.conf import Config as WorldConfig
from ..world.dimension import OVERWORLD
from ..world.game_mode import GAME_MODE_SPECTATOR, GameMode
from ..world.generator.flat import Flat
from ..world.handler import NopHandler
from ..world.world import TICK_MS, World, WorldTypes
from .conf import Config


comptime _JOIN_KEY = "§e%multiplayer.player.joined§r"
"""Go's `chat.MessageJoin` as `SendTranslation` resolves it."""
comptime _QUIT_KEY = "§e%multiplayer.player.left§r"
"""Go's `chat.MessageQuit` as `SendTranslation` resolves it."""
comptime _SHUTDOWN_KEY = "%disconnect.disconnected"
"""Go's `chat.MessageServerDisconnect`, resolved."""
comptime _SPAWN_SEARCH_Y = 32767
"""The spawn Y of a new `level.dat`: find the surface (Go `math.MaxInt16`).
"""
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
    comptime Provider = WorldProvider
    """The vanilla format on disk, or nothing (`[World] SaveData`)."""
    comptime Viewer = SessionViewer
    """Loaders show the world to sessions."""
    comptime Handler = NopHandler
    """No world handler yet."""
    comptime Blocks = VanillaBlocks
    """Every ported block type."""
    comptime Entities = VanillaEntities
    """Every ported entity type."""


def strip_formatting(s: String) -> String:
    """Removes `§x` colour and format codes, for the console."""
    var b = s.as_bytes()
    var out = List[UInt8](capacity=len(b))
    var i = 0
    while i < len(b):
        # `§` is C2 A7 in UTF-8; the code character follows.
        if i + 2 < len(b) and b[i] == 0xC2 and b[i + 1] == 0xA7:
            i += 3
            continue
        out.append(b[i])
        i += 1
    return String(from_utf8_lossy=Span(out))


def termination_signals() raises -> SignalFD:
    """Blocks SIGINT and SIGTERM in every thread, re-executing the program
    once to do so (`signal.block_in_every_thread`), and returns the
    descriptor that receives them, for `Server.close_on_program_end`."""
    try:
        block_in_every_thread([SIGINT, SIGTERM])
    except e:
        print("signals: cannot block in every thread:", e)
    return SignalFD([SIGINT, SIGTERM])


def open_world(conf: Config, now_ms: Int) raises -> World[ServerWorld]:
    """Opens the world in `conf.world_folder` (or one in memory) with
    Dragonfly's default flat generator of grass, two dirt layers and
    bedrock for chunks that are not stored (Go `createWorld`)."""
    var br = ArcPointer(vanilla_block_registry(conf.block_states_path))
    var layers: List[UInt32] = [
        br[].block_runtime_id(Grass()),
        br[].block_runtime_id(Dirt()),
        br[].block_runtime_id(Dirt()),
        br[].block_runtime_id(Bedrock()),
    ]
    var provider = WorldProvider()
    var new_world = True
    if case .Some(folder) = conf.world_folder:
        new_world = not exists(join(folder, "level.dat"))
        provider = WorldProvider.open(folder, br)
    var gen = Flat(Plains(), layers^)
    var fallback = gen.default_spawn(OVERWORLD)
    var wc = WorldConfig[ServerWorld](gen^, provider^, br)
    # The server saves on its own schedule (`Server._save`).
    wc.save_interval_ms = -1
    var w = wc^.new(now_ms)
    if new_world:
        # Go's world without a provider: the generator's spawn.
        w.settings().name = conf.world_name.copy()
        w.set_default_game_mode(conf.default_game_mode)
        w.set_spawn(fallback)
    var spawn = w.spawn()
    if spawn.y() >= _SPAWN_SEARCH_Y:
        var y = w.highest_block(spawn.x(), spawn.z()) + 1
        if y <= w.range().min() + 1:
            # No terrain stored there: the generator's spawn.
            y = fallback.y()
        w.set_spawn(Pos(spawn.x(), y, spawn.z()))
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
    var commands: Registry[CommandSource]
    """The commands players and the console run (Go's global `cmd`
    registry); the built-in ones are registered at start."""
    var _items: List[ItemEntry]
    var _biomes: List[UInt8]
    var _creative: List[UInt8]
    var _crafting: List[UInt8]
    var _trim: List[UInt8]
    var _custom_blocks: List[BlockEntry]
    var _pending: List[MinecraftConn]
    var _closing: List[MinecraftConn]
    var _next_tick: Int
    var _players: Optional[PlayerProvider]
    var _player_data: Dict[UInt128, PlayerData]
    var _next_save: Int
    var _signals: Optional[SignalFD]
    var _console: Optional[LineReader]
    var _close_requested: Bool
    var _closed: Bool
    var _ticks: Int

    def __init__(out self, var conf: Config) raises:
        """Loads the world data and starts listening (Go `Config.New` and
        `Listen`).

        Args:
            conf: The settings.

        Raises:
            If a resource cannot be loaded or the address cannot be bound.
        """
        var world = open_world(conf, monotonic_ms())
        var players = Optional[PlayerProvider](None)
        if case .Some(folder) = conf.players_folder:
            players = PlayerProvider(folder)
        var items = item_entries(conf.vanilla_items_path)
        var biomes = biome_definition_packet(vanilla_biome_registry())
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
        self.commands = Registry[CommandSource]()
        register_builtin_commands(self.commands)
        self._items = items^
        self._biomes = biomes^
        self._creative = item_pks[0].copy()
        self._crafting = item_pks[1].copy()
        self._trim = item_pks[2].copy()
        self._custom_blocks = blocks^
        self._pending = List[MinecraftConn]()
        self._closing = List[MinecraftConn]()
        self._next_tick = monotonic_ms() + TICK_MS
        self._players = players^
        self._player_data = Dict[UInt128, PlayerData]()
        self._next_save = monotonic_ms() + self.conf.save_interval_ms
        self._signals = None
        self._console = None
        self._close_requested = False
        self._closed = False
        self._ticks = 0

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
        """Runs the loop until `close` is requested, then closes the server
        (Go `Listen` and `Accept`, then `Close`)."""
        while not self._close_requested:
            self.step(50)
        self.close()

    def close_on_program_end(mut self, var signals: SignalFD):
        """Makes SIGINT and SIGTERM close the server, saving everything (Go
        `CloseOnProgramEnd`). Create `signals` with `termination_signals()`
        first thing in `main`, which may re-execute the program."""
        self._signals = signals^

    def read_console(mut self):
        """Runs commands typed on standard input as the console."""
        self._console = LineReader(STDIN)

    def request_close(mut self):
        """Makes `run` return after closing the server."""
        self._close_requested = True

    def close_requested(self) -> Bool:
        """Reports whether the server is shutting down."""
        return self._close_requested

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
        if self.conf.save_interval_ms > 0:
            due = min(due, self._next_save)
        var signal_index = -1
        if self._signals:
            signal_index = set.add(self._signals.value().fd())
        var console_index = -1
        if self._console and not self._console.value().eof():
            console_index = set.add(self._console.value().fd())
        _ = set.wait(max(0, min(due - monotonic_ms(), max_wait_ms)))
        if signal_index >= 0 and set.readable(signal_index):
            if self._signals.value().read():
                print("signal received, closing")
                self._close_requested = True
        if console_index >= 0 and (
            set.readable(console_index) or set.failed(console_index)
        ):
            for line in self._console.value().read_lines():
                self.execute_console_command(line)

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

        if self.conf.save_interval_ms > 0 and now >= self._next_save:
            self.save()
            self._next_save = now + self.conf.save_interval_ms

        for _i in range(len(self.sessions)):
            ref s = self.sessions[_i]
            s.flush()
        self._remove_closed_sessions()

    # ===------------------------------------------------------------------=== #
    # Commands
    # ===------------------------------------------------------------------=== #

    def execute_console_command(mut self, line: String):
        """Runs a line typed on the console and prints its output."""
        if line.strip().byte_length() == 0:
            return
        var src = CommandSource(console_at=self._spawn_position())
        execute_command(self, src, line)
        if case .Some(ref o) = src.output:
            for m in o.messages():
                print(strip_formatting(String(m)))
            for e in o.errors():
                print(strip_formatting(String(e)))

    def execute_player_command(mut self, i: Int, line: String):
        """Runs a command line as a player and shows them the output (Go
        `Player.ExecuteCommand`)."""
        var src = CommandSource(self.sessions[i].player)
        var id = self.sessions[i].player.uuid()
        print(t"{src.name} issued command: {line}")
        execute_command(self, src, line)
        if case .Some(ref o) = src.output:
            if case .Some(j) = self.session_index(id):
                self.sessions[j].send_command_output(o)

    def session_index(self, id: UUID) -> Optional[Int]:
        """Returns the index in `sessions` of the player with a UUID."""
        for i in range(len(self.sessions)):
            if self.sessions[i].player.uuid() == id:
                return i
        return None

    def set_player_game_mode(mut self, i: Int, mode: GameMode):
        """Changes a player's game mode and shows it (Go `SetGameMode`)."""
        self.sessions[i].player.set_game_mode(mode)
        self.sessions[i].send_game_mode()
        var p = self.sessions[i].player.copy()
        for j in range(len(self.sessions)):
            if j != i:
                self.sessions[j].view_entity_game_mode(p)

    def teleport_player(mut self, i: Int, pos: Vec3):
        """Teleports a player and shows it to everyone, the player included
        (Go `Player.Teleport`)."""
        self.sessions[i].player.teleport(pos)
        var p = self.sessions[i].player.copy()
        for j in range(len(self.sessions)):
            self.sessions[j].view_entity_teleport(p, pos)

    def broadcast(mut self, message: String):
        """Sends a message to every player and the log (Go `chat.Global`)."""
        print(message)
        for i in range(len(self.sessions)):
            self.sessions[i].send_message(message)

    def max_player_count(self) -> Int:
        """Returns the player limit; without one, one more than are online,
        as Dragonfly's status provider shows."""
        if self.conf.max_players > 0:
            return self.conf.max_players
        return len(self.sessions) + 1

    # ===------------------------------------------------------------------=== #
    # Saving and closing
    # ===------------------------------------------------------------------=== #

    def save(mut self):
        """Saves the world, its settings and `level.dat`, and the data of
        every online player (Go's `World` auto save, plus the rest)."""
        for i in range(len(self.sessions)):
            self._save_player(i)
        self.world.save()
        try:
            self.world.provider().flush_level_dat()
        except e:
            print("save world:", e)
        if self.world.last_error:
            print("world:", self.world.last_error.value())
            self.world.last_error = None

    def _save_player(mut self, i: Int):
        """Go `PlayerProvider.Save` with `Player.Data`."""
        if not self._players:
            return
        ref p = self.sessions[i].player
        var key = uuid_key(p.uuid())
        var data = self._player_data.get(key).or_else(PlayerData())
        data.put_player(p, self.world.dimension().id)
        try:
            self._players.value().save(p.uuid(), data)
        except e:
            print(t"save player data of {p.name()}: {e}")
        self._player_data[key] = data^

    def _load_player(mut self, id: UUID) -> Optional[PlayerData]:
        """Go `PlayerProvider.Load`; None makes the player use defaults."""
        if not self._players:
            return None
        try:
            return self._players.value().load(id)
        except e:
            print(t"load player data of {id}: {e}")
            return None

    def close(mut self):
        """Disconnects every player, saves their data and the world, and
        closes the providers (Go `Server.close`). Calling it again does
        nothing."""
        if self._closed:
            return
        self._closed = True
        self._close_requested = True
        print("server closing")
        while len(self.sessions) > 0:
            self._save_player(0)
            var gone = self.sessions.pop(0)
            gone.close(self.world)
            var c = gone^.into_conn()
            var inner = c^.into_inner()
            inner.disconnect(String(_SHUTDOWN_KEY))
            self._closing.append(inner^)
            self.listener.connection_closed()
        for _i in range(len(self._pending)):
            self._pending[_i].disconnect(String(_SHUTDOWN_KEY))
        if self._players:
            try:
                self._players.value().close()
            except e:
                print("close player provider:", e)
        self.world.close()
        if self.world.last_error:
            print("world:", self.world.last_error.value())
        # Let the disconnects reach the clients.
        var deadline = monotonic_ms() + 2000
        while (
            len(self._closing) + len(self._pending) > 0
            and monotonic_ms() < deadline
        ):
            var set = PollSet()
            for _i in range(len(self._closing)):
                self._closing[_i].add_poll_fds(set)
            for _i in range(len(self._pending)):
                self._pending[_i].add_poll_fds(set)
            try:
                _ = set.wait(10)
            except:
                pass
            var now = monotonic_ms()
            self._poll_closing(now)
            var i = 0
            while i < len(self._pending):
                try:
                    self._pending[i].poll(now)
                except:
                    pass
                if self._pending[i].is_closed():
                    _ = self._pending.pop(i)
                    continue
                i += 1
        print("server closed")

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
        var data = self.default_game_data()
        try:
            var id = UUID.parse(conn.identity_data.identity)
            if case .Some(d) = self._load_player(id):
                # Go `finaliseConn` with the data the player provider loaded.
                data.player_position = vec64_to32(
                    d.position.add(Vec3(0, EYE_HEIGHT, 0))
                )
                data.yaw = Float32(d.yaw)
                data.pitch = Float32(d.pitch)
                if case .Some(mode) = d.mode():
                    data.player_game_mode = game_type_from_mode(mode)
                    if mode == GAME_MODE_SPECTATOR:
                        data.player_game_mode = GAME_TYPE_SPECTATOR
        except:
            pass  # An invalid identity is refused in `_create_player`.
        try:
            conn.start_game(data^)
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
        var pos = self._spawn_position()
        var rot = Rotation()
        var mode = self.world.default_game_mode()
        var stored = self._load_player(uuid)
        if case .Some(ref d) = stored:
            pos = d.position
            rot = d.rotation()
            if case .Some(m) = d.mode():
                mode = m
        self._player_data[uuid_key(uuid)] = stored^.or_else(PlayerData())
        var player = Player(name, conn.identity_data.xuid, uuid, pos, mode, rot)
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
        self.sessions[n].send_available_commands(
            self.commands.commands(), CommandSource(self.sessions[n].player)
        )
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
        if case .Some(line) = res.command:
            self.execute_player_command(i, line)

    def _tick(mut self):
        """Runs the per-tick session work (each session's `background`
        loop in Go); the world ticks on its own deadline."""
        self._ticks += 1
        for i in range(len(self.sessions)):
            self.sessions[i].send_chunks(self.world)
            # Go `background`: enums every second, commands every 5 seconds.
            if self._ticks % 20 == 0 or self._ticks % 100 == 0:
                var src = CommandSource(self.sessions[i].player)
                if self._ticks % 20 == 0:
                    self.sessions[i].resend_enums(self.commands.commands(), src)
                if self._ticks % 100 == 0:
                    _ = self.sessions[i].resend_commands(
                        self.commands.commands(), src
                    )

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
            self._save_player(i)
            var gone = self.sessions.pop(i)
            gone.close(self.world)
            var p = gone.player.copy()
            _ = self._player_data.pop(uuid_key(p.uuid()), PlayerData())
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
