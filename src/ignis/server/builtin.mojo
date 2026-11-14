"""The commands the server registers by default: `/gamemode`, `/tp`,
`/time`, `/list` and `/say`.

Dragonfly ships none; these follow vanilla's syntax and messages (in plain
text, not translations). They act through `ServerTx`, so they run only with
the server's `CommandSource`; with another source they print nothing.
"""

from .. import cmd
from ..mgl64 import Vec3
from ..world.game_mode import GameMode, game_mode_by_id
from .command import CommandSource, ServerTx
from .conf import game_mode_by_name


def register_builtin_commands(mut r: cmd.Registry[CommandSource]):
    """Registers every built-in command."""
    r.register(
        cmd.new[CommandSource, GameModeByName, GameModeByID](
            "gamemode", "Sets a player's game mode.", List[String]()
        )
    )
    r.register(
        cmd.new[
            CommandSource,
            TeleportToPos,
            TeleportTargetsToPos,
            TeleportToTarget,
            TeleportTargetsToTarget,
        ]("tp", "Teleports players.", ["teleport"])
    )
    r.register(
        cmd.new[CommandSource, TimeSet, TimeSetSpec, TimeAdd, TimeQuery](
            "time", "Changes or queries the world's time.", List[String]()
        )
    )
    r.register(
        cmd.new[CommandSource, ListPlayers](
            "list", "Lists the players on the server.", List[String]()
        )
    )
    r.register(
        cmd.new[CommandSource, Say](
            "say", "Sends a message to every player.", List[String]()
        )
    )


# ===----------------------------------------------------------------------=== #
# /gamemode
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct GameModeName(cmd.Enum):
    """A game mode by name, as vanilla's `GameMode` enum."""

    var value: String
    """The chosen option."""

    def __init__(out self):
        """Creates an unset option."""
        self.value = ""

    def type(self) -> String:
        """Returns the enum name."""
        return "GameMode"

    def options[S: cmd.Source](self, src: S) -> List[String]:
        """Lists the game mode names and their short forms."""
        return [
            "survival",
            "creative",
            "adventure",
            "spectator",
            "s",
            "c",
            "a",
        ]

    def set_option(mut self, var option: String):
        """Stores the chosen option."""
        self.value = option^

    def mode(self) -> Optional[GameMode]:
        """Returns the game mode the option names."""
        if self.value == "s":
            return game_mode_by_id(0)
        if self.value == "c":
            return game_mode_by_id(1)
        if self.value == "a":
            return game_mode_by_id(2)
        return game_mode_by_name(self.value)


struct GameModeByName(cmd.Runnable):
    """`/gamemode <mode> [player]`."""

    var mode: GameModeName
    """The game mode."""
    var player: cmd.Optional[List[cmd.Target]]
    """The players; the source itself if left out."""

    def __init__(out self):
        """Creates the runnable with zero parameters."""
        self.mode = GameModeName()
        self.player = cmd.Optional[List[cmd.Target]]()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Sets the game mode."""
        comptime if S == CommandSource:
            _set_game_mode(
                self.mode.mode(),
                self.player.load(),
                rebind[CommandSource](src),
                o,
                rebind[ServerTx](tx),
            )


struct GameModeByID(cmd.Runnable):
    """`/gamemode <0-3> [player]`."""

    var mode: Int
    """The game mode ID."""
    var player: cmd.Optional[List[cmd.Target]]
    """The players; the source itself if left out."""

    def __init__(out self):
        """Creates the runnable with zero parameters."""
        self.mode = 0
        self.player = cmd.Optional[List[cmd.Target]]()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Sets the game mode."""
        comptime if S == CommandSource:
            _set_game_mode(
                game_mode_by_id(self.mode),
                self.player.load(),
                rebind[CommandSource](src),
                o,
                rebind[ServerTx](tx),
            )


def _set_game_mode(
    mode: Optional[GameMode],
    targets: Optional[List[cmd.Target]],
    src: CommandSource,
    mut o: cmd.Output,
    mut tx: ServerTx,
):
    if not mode:
        o.error("Unknown game mode")
        return
    var m = mode.value()
    var victims = _victims(targets, src, o)
    for ref t in victims:
        var i = tx.server().session_index(t.uuid)
        if not i:
            continue
        tx.server().set_player_game_mode(i.value(), m)
        if src.player and src.player.value() == t.uuid:
            o.print(t"Set own game mode to {_title(m)}")
        else:
            o.print(t"Set {t.name}'s game mode to {_title(m)}")


def _title(m: GameMode) -> String:
    var s = String(m)
    if s.byte_length() == 0:
        return s^
    return s[byte=0:1].upper() + String(s[byte=1:])


def _victims(
    targets: Optional[List[cmd.Target]],
    src: CommandSource,
    mut o: cmd.Output,
) -> List[cmd.Target]:
    """The targets given, else the source if it is a player."""
    if case .Some(ref t) = targets:
        if len(t) == 0:
            o.errort(cmd.MESSAGE_NO_TARGETS)
        return t.copy()
    if src.is_console():
        o.error("A player must be specified when running from the console")
        return List[cmd.Target]()
    return [src.target()]


# ===----------------------------------------------------------------------=== #
# /tp
# ===----------------------------------------------------------------------=== #


struct TeleportToPos(cmd.Runnable):
    """`/tp <destination: x y z>`."""

    var destination: Vec3
    """Where to go."""

    def __init__(out self):
        """Creates the runnable with zero parameters."""
        self.destination = Vec3()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Teleports the source."""
        comptime if S == CommandSource:
            ref s = rebind[CommandSource](src)
            _teleport_to_pos(
                _victims(None, s, o),
                self.destination,
                o,
                rebind[ServerTx](tx),
            )


struct TeleportTargetsToPos(cmd.Runnable):
    """`/tp <victim: target> <destination: x y z>`."""

    var victim: List[cmd.Target]
    """Who to teleport."""
    var destination: Vec3
    """Where to."""

    def __init__(out self):
        """Creates the runnable with zero parameters."""
        self.victim = List[cmd.Target]()
        self.destination = Vec3()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Teleports the victims."""
        comptime if S == CommandSource:
            _teleport_to_pos(
                _victims(self.victim.copy(), rebind[CommandSource](src), o),
                self.destination,
                o,
                rebind[ServerTx](tx),
            )


struct TeleportToTarget(cmd.Runnable):
    """`/tp <destination: target>`."""

    var destination: List[cmd.Target]
    """Who to go to."""

    def __init__(out self):
        """Creates the runnable with zero parameters."""
        self.destination = List[cmd.Target]()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Teleports the source to the destination."""
        comptime if S == CommandSource:
            ref s = rebind[CommandSource](src)
            _teleport_to_target(
                _victims(None, s, o), self.destination, o, rebind[ServerTx](tx)
            )


struct TeleportTargetsToTarget(cmd.Runnable):
    """`/tp <victim: target> <destination: target>`."""

    var victim: List[cmd.Target]
    """Who to teleport."""
    var destination: List[cmd.Target]
    """Who to teleport them to."""

    def __init__(out self):
        """Creates the runnable with zero parameters."""
        self.victim = List[cmd.Target]()
        self.destination = List[cmd.Target]()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Teleports the victims to the destination."""
        comptime if S == CommandSource:
            _teleport_to_target(
                _victims(self.victim.copy(), rebind[CommandSource](src), o),
                self.destination,
                o,
                rebind[ServerTx](tx),
            )


def _teleport_to_pos(
    victims: List[cmd.Target], pos: Vec3, mut o: cmd.Output, mut tx: ServerTx
):
    for ref t in victims:
        _teleport(t, pos, tx)
        o.print(t"Teleported {t.name} to {pos.x()}, {pos.y()}, {pos.z()}")


def _teleport_to_target(
    victims: List[cmd.Target],
    destination: List[cmd.Target],
    mut o: cmd.Output,
    mut tx: ServerTx,
):
    if len(destination) != 1:
        o.error("The destination must be exactly one entity")
        return
    ref d = destination[0]
    for ref t in victims:
        _teleport(t, d.position, tx)
        o.print(t"Teleported {t.name} to {d.name}")


def _teleport(t: cmd.Target, pos: Vec3, mut tx: ServerTx):
    if t.player:
        if case .Some(i) = tx.server().session_index(t.uuid):
            tx.server().teleport_player(i, pos)
        return
    tx.server().world.teleport_entity(t.uuid, pos)


# ===----------------------------------------------------------------------=== #
# /time
# ===----------------------------------------------------------------------=== #


@fieldwise_init
struct TimeSpec(cmd.Enum):
    """A named time of day, as vanilla's `TimeSpec` enum."""

    var value: String
    """The chosen option."""

    def __init__(out self):
        """Creates an unset option."""
        self.value = ""

    def type(self) -> String:
        """Returns the enum name."""
        return "TimeSpec"

    def options[S: cmd.Source](self, src: S) -> List[String]:
        """Lists the named times."""
        return ["day", "night", "noon", "midnight", "sunrise", "sunset"]

    def set_option(mut self, var option: String):
        """Stores the chosen option."""
        self.value = option^

    def ticks(self) -> Int:
        """Returns the time of day the name stands for (vanilla's values)."""
        if self.value == "night":
            return 13000
        if self.value == "noon":
            return 6000
        if self.value == "midnight":
            return 18000
        if self.value == "sunrise":
            return 23000
        if self.value == "sunset":
            return 12000
        return 1000


@fieldwise_init
struct TimeQueryKind(cmd.Enum):
    """What `/time query` reports, as vanilla's `TimeQuery` enum."""

    var value: String
    """The chosen option."""

    def __init__(out self):
        """Creates an unset option."""
        self.value = ""

    def type(self) -> String:
        """Returns the enum name."""
        return "TimeQuery"

    def options[S: cmd.Source](self, src: S) -> List[String]:
        """Lists the queries."""
        return ["daytime", "gametime", "day"]

    def set_option(mut self, var option: String):
        """Stores the chosen option."""
        self.value = option^


struct TimeSet(cmd.Runnable):
    """`/time set <amount: int>`."""

    var set: cmd.SubCommand
    """`set`."""
    var amount: Int
    """The time in ticks."""

    def __init__(out self):
        """Creates the runnable with zero parameters."""
        self.set = cmd.SubCommand()
        self.amount = 0

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Sets the time."""
        comptime if S == CommandSource:
            _set_time(self.amount, o, rebind[ServerTx](tx))


struct TimeSetSpec(cmd.Runnable):
    """`/time set <time: TimeSpec>`."""

    var set: cmd.SubCommand
    """`set`."""
    var time: TimeSpec
    """The named time."""

    def __init__(out self):
        """Creates the runnable with zero parameters."""
        self.set = cmd.SubCommand()
        self.time = TimeSpec()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Sets the time."""
        comptime if S == CommandSource:
            _set_time(self.time.ticks(), o, rebind[ServerTx](tx))


struct TimeAdd(cmd.Runnable):
    """`/time add <amount: int>`."""

    var add: cmd.SubCommand
    """`add`."""
    var amount: Int
    """Ticks to add."""

    def __init__(out self):
        """Creates the runnable with zero parameters."""
        self.add = cmd.SubCommand()
        self.amount = 0

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Advances the time."""
        comptime if S == CommandSource:
            ref t = rebind[ServerTx](tx)
            _set_time(t.server().world.time() + self.amount, o, t)


struct TimeQuery(cmd.Runnable):
    """`/time query <daytime|gametime|day>`."""

    var query: cmd.SubCommand
    """`query`."""
    var what: TimeQueryKind
    """What to report."""

    def __init__(out self):
        """Creates the runnable with zero parameters."""
        self.query = cmd.SubCommand()
        self.what = TimeQueryKind()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Reports the time."""
        comptime if S == CommandSource:
            ref t = rebind[ServerTx](tx)
            var time = t.server().world.time()
            if self.what.value == "daytime":
                time = time % 24000
            elif self.what.value == "day":
                time = time // 24000
            o.print(t"Time is {time}")


def _set_time(time: Int, mut o: cmd.Output, mut tx: ServerTx):
    tx.server().world.set_time(time)
    o.print(t"Set the time to {time}")


# ===----------------------------------------------------------------------=== #
# /list and /say
# ===----------------------------------------------------------------------=== #


struct ListPlayers(cmd.Runnable):
    """`/list`."""

    def __init__(out self):
        """Creates the runnable."""
        pass

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Prints the online players."""
        comptime if S == CommandSource:
            ref t = rebind[ServerTx](tx)
            var names = String()
            for ref p in t.players():
                if names.byte_length() > 0:
                    names += ", "
                names += p.name
            var n = t.server().player_count()
            o.print(
                t"There are {n}/{t.server().max_player_count()} players online:"
            )
            o.print(names)


struct Say(cmd.Runnable):
    """`/say <message: text>`."""

    var message: cmd.Varargs
    """The message."""

    def __init__(out self):
        """Creates the runnable with zero parameters."""
        self.message = cmd.Varargs()

    def run[
        S: cmd.Source
    ](mut self, mut src: S, mut o: cmd.Output, mut tx: S.Tx):
        """Sends `[name] message` to every player."""
        comptime if S == CommandSource:
            ref s = rebind[CommandSource](src)
            rebind[ServerTx](tx).server().broadcast(
                String(t"[{s.name}] {self.message}")
            )
