"""Running commands on the server: the server's `cmd.Source` (a player or
the console), the `Tx` commands receive, and Go's `Player.ExecuteCommand`.

Dragonfly's `*player.Player` is a `cmd.Source` and commands get the world
transaction. A `Registry` has one source type, so `CommandSource` stands for
either a player or the console, and `ServerTx` gives commands the server
(sessions and world) the way Go's `*world.Tx` gives them the world and its
players. The output a command produces is kept on the source and delivered
by the server afterwards: to the player as `CommandOutput`, or printed for
the console.
"""

from minecraft.protocol.uuid import UUID

from ..cmd.output import MESSAGE_UNKNOWN, Output
from ..cmd.source import Source
from ..cmd.target import Target, TargetProvider
from ..mgl64 import Vec3
from ..player.player import Player
from .server import Server

comptime CONSOLE_NAME = "Server"
"""The name the console uses in `/say` (vanilla's name for it)."""


struct CommandSource(Copyable, Source):
    """A player running a command, or the console (Go: `*player.Player` and
    a console source)."""

    comptime Tx = ServerTx
    """Commands receive the server."""

    var player: Optional[UUID]
    """The player's UUID, or None for the console."""
    var name: String
    """The player's name, or `Server`."""
    var pos: Vec3
    """The position relative coordinates and `@p` start from."""
    var output: Optional[Output]
    """The output of the last command run, set by `send_command_output`."""

    def __init__(out self, p: Player):
        """Creates the source of a player."""
        self.player = p.uuid()
        self.name = p.name()
        self.pos = p.position()
        self.output = None

    def __init__(out self, *, console_at: Vec3):
        """Creates the console source, placed at the world spawn."""
        self.player = None
        self.name = String(CONSOLE_NAME)
        self.pos = console_at
        self.output = None

    def is_console(self) -> Bool:
        """Reports whether this is the console."""
        return not self.player

    def position(self) -> Vec3:
        """Returns the source's position (Go `Position`)."""
        return self.pos

    def target(self) -> Target:
        """Returns the source as a target, for `@s`; the console is not a
        player."""
        if case .Some(id) = self.player:
            return Target(id, self.name.copy(), self.pos, True)
        return Target(UUID(), self.name.copy(), self.pos, False)

    def send_command_output(mut self, o: Output):
        """Keeps the output for the server to deliver (Go
        `SendCommandOutput`)."""
        self.output = o.copy()


struct ServerTx(Movable, TargetProvider):
    """What commands act on: the server, its sessions and its world (Go
    `*world.Tx`). It is only valid while the server runs a command."""

    var _srv: Pointer[Server, MutUntrackedOrigin]

    def __init__(out self, srv: Pointer[Server, MutUntrackedOrigin]):
        """Wraps the server running the command."""
        self._srv = srv

    def server(self) -> ref[MutUntrackedOrigin] Server:
        """Returns the server."""
        return self._srv[]

    def attached(self) -> Bool:
        """Reports that selectors have a world to choose from."""
        return True

    def players(self) -> List[Target]:
        """Lists the online players (Go `tx.Players()`)."""
        var out = List[Target]()
        ref srv = self._srv[]
        for i in range(len(srv.sessions)):
            ref p = srv.sessions[i].player
            out.append(Target(p.uuid(), p.name(), p.position(), True))
        return out^

    def entities(self) -> List[Target]:
        """Lists the players and the world's entities (Go
        `tx.Entities()`)."""
        var out = self.players()
        ref w = self._srv[].world
        for id in w.entities():
            if case .Some(ref h) = w.entity(id):
                out.append(Target(id, h.data.name.copy(), h.data.pos, False))
        return out^


def execute_command(mut srv: Server, mut src: CommandSource, line: String):
    """Runs a command line as a source (Go `Player.ExecuteCommand`): the
    line is split at spaces, a player's must start with `/` (the console's
    may), an unknown name answers `commands.generic.unknown`. The output is
    left in `src.output`."""
    var args = line.split(" ")
    var first = String(args[0])
    var name: String
    if first.startswith("/"):
        name = String(first[byte=1:])
    elif src.is_console():
        name = first^
    else:
        return
    var command = srv.commands.by_alias(name)
    if not command:
        var o = Output()
        o.errort(MESSAGE_UNKNOWN, name)
        src.send_command_output(o)
        return
    var rest = String()
    for i in range(1, len(args)):
        if i > 1:
            rest += " "
        rest += args[i]
    var tx = ServerTx(Pointer(to=srv).unsafe_origin_cast[MutUntrackedOrigin]())
    command.value().execute(rest, src, tx)
