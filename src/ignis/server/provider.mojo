"""The world provider the server picks from `config.toml` (Dragonfly
`server/conf.go`: `mcdb.Config.Open(World.Folder)` when `World.SaveData` is
set, else `world.NopProvider`).

`ServerWorld` names one provider type, so `WorldProvider` holds either the
on-disk world or nothing and forwards to it.
"""

from std.memory import ArcPointer

from minecraft.protocol.uuid import UUID

from ..block.cube.pos import Pos
from ..world.block_registry import BasicBlockRegistry
from ..world.chunk.column import Column
from ..world.dimension import Dimension
from ..world.mcdb.db import DB
from ..world.position import ChunkPos
from ..world.provider import NopProvider, Provider
from ..world.settings import Settings


struct WorldProvider(Movable, Provider):
    """A vanilla world on disk (Go `mcdb.DB`) or nothing (Go `NopProvider`)."""

    var _db: Optional[DB]
    var _nop: NopProvider

    def __init__(out self):
        """Creates a provider that stores nothing."""
        self._db = None
        self._nop = NopProvider()

    def __init__(out self, var db: DB):
        """Wraps an opened world."""
        self._db = db^
        self._nop = NopProvider()

    @staticmethod
    def open(
        folder: StringSlice, blocks: ArcPointer[BasicBlockRegistry]
    ) raises -> WorldProvider:
        """Opens or creates the world in `folder` (Go `mcdb.Config.Open`)."""
        return WorldProvider(DB.open(folder, blocks))

    def on_disk(self) -> Bool:
        """Reports whether the world is kept on disk."""
        return Bool(self._db)

    def settings(mut self) -> Optional[Settings]:
        """Returns the stored settings, or None for a new world in memory."""
        if self._db:
            return self._db.value().settings()
        return self._nop.settings()

    def random_tick_speed(mut self) -> Optional[Int]:
        """Returns the `randomtickspeed` game rule of a world on disk."""
        if self._db:
            return Int(self._db.value().level_data().random_tick_speed)
        return None

    def save_settings(mut self, s: Settings) raises:
        """Stores the settings."""
        if self._db:
            self._db.value().save_settings(s)

    def load_player_spawn_position(mut self, id: UUID) raises -> Optional[Pos]:
        """Loads a player's spawn position."""
        if self._db:
            return self._db.value().load_player_spawn_position(id)
        return None

    def save_player_spawn_position(mut self, id: UUID, pos: Pos) raises:
        """Saves a player's spawn position."""
        if self._db:
            self._db.value().save_player_spawn_position(id, pos)

    def load_column(
        mut self, pos: ChunkPos, dim: Dimension
    ) raises -> Optional[Column]:
        """Loads a column; None makes the world generate it."""
        if self._db:
            return self._db.value().load_column(pos, dim)
        return None

    def store_column(
        mut self, pos: ChunkPos, dim: Dimension, var col: Column
    ) raises:
        """Stores a column."""
        if self._db:
            self._db.value().store_column(pos, dim, col^)

    def close(mut self) raises:
        """Writes `level.dat` and syncs the database (Go `DB.Close`)."""
        if self._db:
            self._db.value().close()

    def flush_level_dat(mut self) raises:
        """Writes `level.dat` and syncs the database without closing, so that
        a periodic save survives a crash (Go writes `level.dat` only on
        close)."""
        if self._db:
            self._db.value().close()
