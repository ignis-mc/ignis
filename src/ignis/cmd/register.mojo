"""The command registry (Dragonfly `server/cmd/register.go`).

Go keeps the registered commands in a package-level `sync.Map`. Ignis has
no globals, so the registry is a value the server owns and passes to
whatever executes or lists commands.
"""

from .command import Command
from .source import Source


struct Registry[S: Source](Copyable, Defaultable):
    """Registered commands by name and alias (Go: the `commands` map)."""

    var _commands: Dict[String, Command[Self.S]]

    def __init__(out self):
        """Creates an empty registry."""
        self._commands = Dict[String, Command[Self.S]]()

    def register(mut self, command: Command[Self.S]):
        """Registers a command under its name and every alias, replacing any
        command registered under the same names (Go `Register`)."""
        self._commands[command.name()] = command.copy()
        for alias in command.aliases():
            self._commands[alias] = command.copy()

    def by_alias(self, alias: String) -> Optional[Command[Self.S]]:
        """Looks up a command by name or alias (Go `ByAlias`)."""
        var c = self._commands.get(alias)
        if c:
            return c.take()
        return None

    def commands(self) -> ref[self._commands] Dict[String, Command[Self.S]]:
        """Gets every command by the alias it was registered under (Go
        `Commands`); a command appears once per alias."""
        return self._commands
