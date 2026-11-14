"""World providers, ported from Dragonfly `server/world/provider.go`.

A provider reads and writes a world's chunks and settings. Go's default is
`NopProvider`, which stores nothing; Ignis adds `MemoryProvider`, which
keeps stored columns in memory so that unloaded chunks come back as they
were. A disk provider (Go's `mcdb`) needs the block state upgrader and is
not ported yet.

Calls run on the loop thread; Go's `lockedProvider` is not needed. Errors
raise; a column that does not exist is None (Go's `leveldb.ErrNotFound`).
"""

from std.collections import Dict

from minecraft.protocol.uuid import UUID

from ..block.cube.pos import Pos
from .chunk.column import Column
from .dimension import Dimension
from .position import ChunkPos
from .settings import Settings


trait Provider(Deinitable, Movable):
    """Provides world data to a World (Go `Provider`)."""

    def settings(mut self) -> Optional[Settings]:
        """Loads the world's settings (Go `Settings`).

        Returns:
            The settings, or None to have the world use default settings
            with the generator's spawn (what Go's `Config.New` does without
            a provider).
        """
        ...

    def save_settings(mut self, s: Settings) raises:
        """Saves the world's settings (Go `SaveSettings`).

        Args:
            s: The settings.

        Raises:
            If they cannot be saved.
        """
        ...

    def load_player_spawn_position(mut self, id: UUID) raises -> Optional[Pos]:
        """Loads a player's spawn position (Go `LoadPlayerSpawnPosition`).

        Args:
            id: The player's UUID.

        Returns:
            The position, or None if the player has none.

        Raises:
            If it cannot be read.
        """
        ...

    def save_player_spawn_position(mut self, id: UUID, pos: Pos) raises:
        """Saves a player's spawn position (Go `SavePlayerSpawnPosition`).

        Args:
            id: The player's UUID.
            pos: The position.

        Raises:
            If it cannot be saved.
        """
        ...

    def load_column(
        mut self, pos: ChunkPos, dim: Dimension
    ) raises -> Optional[Column]:
        """Loads a column (Go `LoadColumn`).

        Args:
            pos: The chunk position.
            dim: The dimension.

        Returns:
            The column, or None if it was never stored.

        Raises:
            If it exists but cannot be read.
        """
        ...

    def store_column(
        mut self, pos: ChunkPos, dim: Dimension, var col: Column
    ) raises:
        """Stores a column (Go `StoreColumn`).

        Args:
            pos: The chunk position.
            dim: The dimension.
            col: The column.

        Raises:
            If it cannot be stored.
        """
        ...

    def close(mut self) raises:
        """Closes the provider (Go `Close`).

        Raises:
            If closing fails.
        """
        ...


@fieldwise_init
struct NopProvider(Defaultable, Provider):
    """A provider that stores nothing (Go `NopProvider`)."""

    var set: Optional[Settings]
    """The settings to start worlds with, or None for defaults."""

    def __init__(out self):
        """Creates a provider that gives worlds default settings."""
        self.set = None

    def settings(mut self) -> Optional[Settings]:
        """Returns the settings passed on creation.

        Returns:
            The settings, or None.
        """
        return self.set.copy()

    def save_settings(mut self, s: Settings) raises:
        """Does nothing.

        Args:
            s: The settings.

        Raises:
            Never; the signature follows the trait.
        """
        pass

    def load_player_spawn_position(mut self, id: UUID) raises -> Optional[Pos]:
        """Returns no spawn position.

        Args:
            id: The player's UUID.

        Returns:
            None.

        Raises:
            Never; the signature follows the trait.
        """
        return None

    def save_player_spawn_position(mut self, id: UUID, pos: Pos) raises:
        """Does nothing.

        Args:
            id: The player's UUID.
            pos: The position.

        Raises:
            Never; the signature follows the trait.
        """
        pass

    def load_column(
        mut self, pos: ChunkPos, dim: Dimension
    ) raises -> Optional[Column]:
        """Returns no column.

        Args:
            pos: The chunk position.
            dim: The dimension.

        Returns:
            None.

        Raises:
            Never; the signature follows the trait.
        """
        return None

    def store_column(
        mut self, pos: ChunkPos, dim: Dimension, var col: Column
    ) raises:
        """Does nothing.

        Args:
            pos: The chunk position.
            dim: The dimension.
            col: The column.

        Raises:
            Never; the signature follows the trait.
        """
        pass

    def close(mut self) raises:
        """Does nothing.

        Raises:
            Never; the signature follows the trait.
        """
        pass


@fieldwise_init
struct _ColumnKey(Equatable, Hashable, ImplicitlyCopyable):
    var dim: Int
    var pos: ChunkPos


struct MemoryProvider(Defaultable, Provider):
    """A provider that keeps everything in memory: stored columns load back
    unchanged until the process exits."""

    var _set: Optional[Settings]
    var _columns: Dict[_ColumnKey, Column]
    var _spawns: Dict[UInt128, Pos]

    def __init__(out self):
        """Creates an empty provider; worlds start with default settings."""
        self._set = None
        self._columns = Dict[_ColumnKey, Column]()
        self._spawns = Dict[UInt128, Pos]()

    def settings(mut self) -> Optional[Settings]:
        """Returns the settings last saved.

        Returns:
            The settings, or None before the first save.
        """
        return self._set.copy()

    def save_settings(mut self, s: Settings) raises:
        """Keeps the settings.

        Args:
            s: The settings.

        Raises:
            Never; the signature follows the trait.
        """
        self._set = s.copy()

    def load_player_spawn_position(mut self, id: UUID) raises -> Optional[Pos]:
        """Returns a saved spawn position.

        Args:
            id: The player's UUID.

        Returns:
            The position, or None.

        Raises:
            Never; the signature follows the trait.
        """
        return self._spawns.get(uuid_key(id))

    def save_player_spawn_position(mut self, id: UUID, pos: Pos) raises:
        """Keeps a spawn position.

        Args:
            id: The player's UUID.
            pos: The position.

        Raises:
            Never; the signature follows the trait.
        """
        self._spawns[uuid_key(id)] = pos

    def load_column(
        mut self, pos: ChunkPos, dim: Dimension
    ) raises -> Optional[Column]:
        """Returns a copy of a stored column.

        Args:
            pos: The chunk position.
            dim: The dimension.

        Returns:
            The column, or None if it was never stored.

        Raises:
            Never; the signature follows the trait.
        """
        return self._columns.get(_ColumnKey(dim.id, pos))

    def store_column(
        mut self, pos: ChunkPos, dim: Dimension, var col: Column
    ) raises:
        """Keeps a column, replacing an earlier one.

        Args:
            pos: The chunk position.
            dim: The dimension.
            col: The column.

        Raises:
            Never; the signature follows the trait.
        """
        self._columns[_ColumnKey(dim.id, pos)] = col^

    def close(mut self) raises:
        """Does nothing; the data stays available.

        Raises:
            Never; the signature follows the trait.
        """
        pass

    def column_count(self) -> Int:
        """Returns how many columns are stored.

        Returns:
            The count.
        """
        return len(self._columns)


def uuid_key(id: UUID) -> UInt128:
    """Returns a UUID as an integer, for use as a `Dict` key.

    Args:
        id: The UUID.

    Returns:
        The 16 bytes, big endian.
    """
    var k = UInt128(0)
    for i in range(16):
        k = (k << 8) | UInt128(id.bytes[i])
    return k
