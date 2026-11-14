"""The source of a command execution (Dragonfly `server/cmd/source.go`)."""

from ..mgl64 import Vec3
from .output import Output
from .target import Target, TargetProvider


trait Source:
    """Something that runs commands: a player, a console (Go `cmd.Source`).

    Go's `Source` embeds `Target`; here `position` and `target` provide the
    same. `Tx` replaces Go's `*world.Tx` argument: it is what the source
    passes to `Command.execute` and what `Runnable.run` receives, and it
    lists the entities target selectors choose from.
    """

    comptime Tx: TargetProvider
    """The world view handed to commands (Go `*world.Tx`)."""

    def position(self) -> Vec3:
        """Gets the source's position (Go `Target.Position`), used by `@p`."""
        ...

    def target(self) -> Target:
        """Gets the source as a target, for `@s`."""
        ...

    def send_command_output(mut self, o: Output):
        """Delivers the output of a command (Go `SendCommandOutput`).

        `Command.execute` calls it after every execution.
        """
        ...
