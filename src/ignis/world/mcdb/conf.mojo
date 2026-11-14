"""Provider configuration, ported from Dragonfly
`server/world/mcdb/conf.go`."""

from std.memory import ArcPointer

from ...leveldb.options import KIB, Options
from ..block_registry import BasicBlockRegistry
from .db import DB


struct Config(Movable):
    """The optional parameters of a `DB` (Go `Config`). Go's `Log` is
    dropped: errors raise, and the few that Go only logs are noted where
    they happen."""

    var ldb_options: Options
    """LevelDB options; a zero block size becomes 16 KiB (Go
    `LDBOptions`)."""
    var blocks: ArcPointer[BasicBlockRegistry]
    """The finalized registry used to encode and decode chunks; pass the
    one the world uses (Go `Blocks`)."""

    def __init__(out self, blocks: ArcPointer[BasicBlockRegistry]):
        """Creates the default configuration.

        Args:
            blocks: The finalized block registry.
        """
        self.ldb_options = Options()
        self.ldb_options.block_size = 16 * KIB
        self.blocks = blocks

    def open(var self, dir: StringSlice) raises -> DB:
        """Opens or creates the world in `dir` (Go `Config.Open`).

        Args:
            dir: The world directory (holding `level.dat` and `db/`).

        Returns:
            The provider.

        Raises:
            If `level.dat` is unsupported or unreadable, or the database
            cannot be opened.
        """
        if self.ldb_options.block_size == 0:
            self.ldb_options.block_size = 16 * KIB
        return DB(dir, self.ldb_options.copy(), self.blocks)
