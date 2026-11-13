"""Server configuration, ported from Dragonfly `server/conf.go`.

`UserConfig` is what `config.toml` holds, with Dragonfly's table and key
names (`[Network] Address`, `[Server] Name`, ...) so that a Dragonfly
config file is read as-is; keys Ignis does not use yet are accepted and
ignored. `Config` is what the server runs with (Go `server.Config`).

Ignis-only keys, marked in `default_config_toml`:

- `[Network] LANDiscovery`: also answer LAN discovery on UDP 7551. Ignis is
  NetherNet only, so `Transport` must contain `nethernet` if it is set.
- `[World] Name`: the world name in StartGame (Go takes it from the level
  data, which Ignis does not store yet).
- `[World] GameMode`: the default game mode (Go's `World.DefaultGameMode`
  from the level data).

The view distance is `[Players] MaximumChunkRadius`, as in Dragonfly; the
client's own setting applies below it. Dragonfly has no simulation
distance setting, and neither does Ignis yet.
"""

from std.os.path import exists

from ..internal.toml import TomlDocument, parse_toml, toml_quote
from ..world.game_mode import GAME_MODE_SURVIVAL, GameMode, game_mode_by_name


struct UserConfig(Copyable, Defaultable):
    """The contents of `config.toml` (Go `UserConfig`)."""

    var network_address: String
    """Go `Network.Address`: the HTTP signaling address players join."""
    var network_lan_discovery: Bool
    """Ignis: also answer LAN discovery."""
    var server_name: String
    """Go `Server.Name`: the name in the server list."""
    var server_auth_enabled: Bool
    """Go `Server.AuthEnabled`: require an Xbox Live sign-in."""
    var server_disable_join_quit_messages: Bool
    """Go `Server.DisableJoinQuitMessages`."""
    var server_mute_emote_chat: Bool
    """Go `Server.MuteEmoteChat`."""
    var world_name: String
    """Ignis `World.Name`."""
    var world_game_mode: String
    """Ignis `World.GameMode`: `survival`, `creative`, `adventure` or
    `spectator`."""
    var world_folder: String
    """Go `World.Folder` (worlds are not saved yet)."""
    var players_max_count: Int
    """Go `Players.MaxCount`; 0 means no limit."""
    var players_maximum_chunk_radius: Int
    """Go `Players.MaximumChunkRadius`."""

    def __init__(out self):
        """Creates Dragonfly's defaults (Go `DefaultConfig`), listening on
        all interfaces at the port Bedrock uses by default."""
        self.network_address = "0.0.0.0:19132"
        self.network_lan_discovery = False
        self.server_name = "Ignis Server"
        self.server_auth_enabled = True
        self.server_disable_join_quit_messages = False
        self.server_mute_emote_chat = False
        self.world_name = "World"
        self.world_game_mode = "survival"
        self.world_folder = "world"
        self.players_max_count = 0
        self.players_maximum_chunk_radius = 32

    @staticmethod
    def from_toml(text: StringSlice) raises -> UserConfig:
        """Reads a `config.toml`; missing keys keep their defaults.

        Args:
            text: The file contents.

        Returns:
            The configuration.

        Raises:
            If the text is not valid in the TOML subset, a value has the
            wrong type, or `Transport` lacks `nethernet`.
        """
        var doc = parse_toml(text)
        var c = UserConfig()
        c.network_address = doc.get_string("Network.Address", c.network_address)
        var transports = doc.get_string_list("Network.Transport", ["nethernet"])
        if "nethernet" not in transports:
            raise Error(
                "config: Network.Transport must include nethernet (Ignis has"
                " no RakNet)"
            )
        c.network_lan_discovery = doc.get_bool(
            "Network.LANDiscovery", c.network_lan_discovery
        )
        c.server_name = doc.get_string("Server.Name", c.server_name)
        c.server_auth_enabled = doc.get_bool(
            "Server.AuthEnabled", c.server_auth_enabled
        )
        c.server_disable_join_quit_messages = doc.get_bool(
            "Server.DisableJoinQuitMessages",
            c.server_disable_join_quit_messages,
        )
        c.server_mute_emote_chat = doc.get_bool(
            "Server.MuteEmoteChat", c.server_mute_emote_chat
        )
        c.world_name = doc.get_string("World.Name", c.world_name)
        c.world_game_mode = doc.get_string("World.GameMode", c.world_game_mode)
        c.world_folder = doc.get_string("World.Folder", c.world_folder)
        c.players_max_count = doc.get_int(
            "Players.MaxCount", c.players_max_count
        )
        c.players_maximum_chunk_radius = doc.get_int(
            "Players.MaximumChunkRadius", c.players_maximum_chunk_radius
        )
        return c^

    def to_toml(self) -> String:
        """Writes the configuration as a `config.toml`.

        Returns:
            The file contents, with comments on the Ignis-only keys.
        """
        var s = String()
        s += "[Network]\n"
        s += String(t"Address = {toml_quote(self.network_address)}\n")
        s += 'Transport = ["nethernet"]\n'
        s += "# Ignis: also answer LAN discovery on UDP 7551.\n"
        s += String(t"LANDiscovery = {_bool(self.network_lan_discovery)}\n\n")
        s += "[Server]\n"
        s += String(t"Name = {toml_quote(self.server_name)}\n")
        s += String(t"AuthEnabled = {_bool(self.server_auth_enabled)}\n")
        s += String(
            t"DisableJoinQuitMessages ="
            t" {_bool(self.server_disable_join_quit_messages)}\n"
        )
        s += String(t"MuteEmoteChat = {_bool(self.server_mute_emote_chat)}\n\n")
        s += "[World]\n"
        s += "# Ignis: the world name and default game mode.\n"
        s += String(t"Name = {toml_quote(self.world_name)}\n")
        s += String(t"GameMode = {toml_quote(self.world_game_mode)}\n")
        s += String(t"Folder = {toml_quote(self.world_folder)}\n\n")
        s += "[Players]\n"
        s += String(t"MaxCount = {self.players_max_count}\n")
        s += String(
            t"MaximumChunkRadius = {self.players_maximum_chunk_radius}\n"
        )
        return s^

    def config(self) raises -> Config:
        """Converts to the server's settings (Go `UserConfig.Config`).

        Returns:
            The settings.

        Raises:
            If the game mode is unknown.
        """
        var c = Config()
        c.address = self.network_address.copy()
        c.lan_discovery = self.network_lan_discovery
        c.name = self.server_name.copy()
        c.auth_disabled = not self.server_auth_enabled
        c.max_players = self.players_max_count
        c.max_chunk_radius = self.players_maximum_chunk_radius
        c.join_quit_messages = not self.server_disable_join_quit_messages
        c.mute_emote_chat = self.server_mute_emote_chat
        c.world_name = self.world_name.copy()
        var mode = game_mode_by_name(self.world_game_mode)
        if not mode:
            raise Error(t"config: unknown game mode {self.world_game_mode}")
        c.default_game_mode = mode.value()
        return c^


def _bool(b: Bool) -> String:
    return "true" if b else "false"


struct Config(Copyable, Defaultable):
    """The settings a `Server` runs with (Go `server.Config`)."""

    var address: String
    """The signaling address to listen on."""
    var lan_discovery: Bool
    """Whether to answer LAN discovery."""
    var name: String
    """The server name (Go `Name`)."""
    var auth_disabled: Bool
    """Whether players may join without Xbox Live (Go
    `AuthDisabled`)."""
    var max_players: Int
    """The player limit, 0 for none (Go `MaxPlayers`)."""
    var max_chunk_radius: Int
    """The largest chunk radius (Go `MaxChunkRadius`)."""
    var join_quit_messages: Bool
    """Whether to broadcast join and quit messages (Go's `JoinMessage`
    and `QuitMessage` being set)."""
    var mute_emote_chat: Bool
    """Go `MuteEmoteChat`."""
    var world_name: String
    """The world name."""
    var default_game_mode: GameMode
    """The game mode of new players."""
    var block_states_path: String
    """Where `block_states.nbt` is."""
    var vanilla_items_path: String
    """Where `vanilla_items.nbt` is."""
    var biome_definitions_path: String
    """Where `biome_definitions.bin` is."""
    var data_driven_blocks_path: String
    """Where `data_driven_blocks.nbt` is."""

    def __init__(out self):
        """Creates the settings of `UserConfig()`."""
        self.address = "0.0.0.0:19132"
        self.lan_discovery = False
        self.name = "Ignis Server"
        self.auth_disabled = False
        self.max_players = 0
        self.max_chunk_radius = 32
        self.join_quit_messages = True
        self.mute_emote_chat = False
        self.world_name = "World"
        self.default_game_mode = GAME_MODE_SURVIVAL
        self.block_states_path = "resources/block_states.nbt"
        self.vanilla_items_path = "resources/vanilla_items.nbt"
        self.biome_definitions_path = "resources/biome_definitions.bin"
        self.data_driven_blocks_path = "resources/data_driven_blocks.nbt"


def load_user_config(path: String) raises -> UserConfig:
    """Reads `config.toml`, writing the defaults there first if the file
    does not exist (what Dragonfly's `main.go` does).

    Args:
        path: The path of the file.

    Returns:
        The configuration.

    Raises:
        If the file cannot be read or written, or is invalid.
    """
    if not exists(path):
        var c = UserConfig()
        with open(path, "w") as f:
            f.write(c.to_toml())
        return c^
    var text: String
    with open(path, "r") as f:
        text = f.read()
    return UserConfig.from_toml(text)
