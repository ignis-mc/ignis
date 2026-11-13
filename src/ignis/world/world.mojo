"""The world, ported from the parts of Dragonfly `server/world/world.go`,
`settings.go`, `tick.go` and `conf.go` the first playable server needs.

This is the smallest `World` that lets players join a generated world:
chunks are generated on first use and kept in memory (there is no provider
or unloading yet), and a tick advances the time. `World.Exec` and `Tx` are
gone: the server's one loop calls the world directly (see
`docs/architecture.md`). Names follow Dragonfly so the world runtime port
can grow this file in place.
"""

from std.collections import Dict

from ..block.cube.pos import Pos
from ..block.cube.range import Range
from .block_registry import BasicBlockRegistry
from .chunk.chunk import Chunk
from .chunk.heightmap import HeightMap
from .dimension import Dimension, OVERWORLD
from .game_mode import GAME_MODE_SURVIVAL, GameMode
from .generator import Generator
from .position import ChunkPos


comptime TICKS_PER_SECOND = 20
"""How often the world ticks (Go's ticker interval is a twentieth of a
second)."""
comptime TICK_MS = 1000 // TICKS_PER_SECOND
"""The length of one tick in milliseconds."""


struct Settings(Copyable):
    """The persistent settings of a world (Go `world.Settings`)."""

    var name: String
    """The name shown in the world list (Go `Name`)."""
    var spawn: Pos
    """Where new players spawn (Go `Spawn`)."""
    var time: Int64
    """The time of day in ticks (Go `Time`)."""
    var time_cycle: Bool
    """Whether time advances (Go `TimeCycle`)."""
    var current_tick: Int64
    """The number of ticks since the world was created (Go
    `CurrentTick`)."""
    var default_game_mode: GameMode
    """The game mode of new players (Go `DefaultGameMode`)."""
    var difficulty: Int
    """The difficulty ID, 0 peaceful to 3 hard (Go `Difficulty`)."""

    def __init__(out self):
        """Creates the settings Go's `defaultSettings` returns."""
        self.name = "World"
        self.spawn = Pos(0, 0, 0)
        self.time = 6000
        self.time_cycle = True
        self.current_tick = 0
        self.default_game_mode = GAME_MODE_SURVIVAL
        self.difficulty = 2


def chunk_key(pos: ChunkPos) -> Int:
    """Packs a chunk position into one map key.

    Args:
        pos: The chunk position.

    Returns:
        X in the high 32 bits and Z in the low 32 bits.
    """
    return (Int(pos.x()) << 32) | (Int(pos.z()) & 0xFFFF_FFFF)


def chunk_pos_from_block(x: Float64, z: Float64) -> ChunkPos:
    """Returns the chunk holding a position (Go `chunkPosFromVec3`).

    Args:
        x: The X coordinate.
        z: The Z coordinate.

    Returns:
        The chunk position.
    """
    return ChunkPos(Int32(_floor(x)) >> 4, Int32(_floor(z)) >> 4)


def _floor(v: Float64) -> Int:
    var i = Int(v)
    if Float64(i) > v:
        i -= 1
    return i


struct World[G: Generator & Copyable & Deinitable](Movable):
    """A generated world of one dimension, held in memory.

    Parameters:
        G: The generator type.
    """

    var _dim: Dimension
    var _br: BasicBlockRegistry
    var _gen: Self.G
    var _set: Settings
    var _chunks: List[Chunk]
    var _index: Dict[Int, Int]

    def __init__(
        out self,
        var br: BasicBlockRegistry,
        var gen: Self.G,
        var settings: Settings,
        dim: Dimension = OVERWORLD,
    ):
        """Creates a world (Go `Config.New`). A spawn of (0, 0, 0) is
        replaced by the generator's default spawn, as Go does for a new
        world.

        Args:
            br: The finalized block registry.
            gen: The generator of new chunks.
            settings: The world settings.
            dim: The dimension.
        """
        if settings.spawn == Pos(0, 0, 0):
            settings.spawn = gen.default_spawn(dim)
        self._dim = dim
        self._br = br^
        self._gen = gen^
        self._set = settings^
        self._chunks = List[Chunk]()
        self._index = Dict[Int, Int]()

    def name(self) -> String:
        """Returns the name of the world (Go `Name`).

        Returns:
            The name from the settings.
        """
        return self._set.name.copy()

    def dimension(self) -> Dimension:
        """Returns the dimension of the world (Go `Dimension`).

        Returns:
            The dimension.
        """
        return self._dim

    def range(self) -> Range:
        """Returns the vertical range of the world (Go `Range`).

        Returns:
            The building range of the dimension.
        """
        return self._dim.range()

    def block_registry(ref self) -> ref[self._br] BasicBlockRegistry:
        """Returns the block registry (Go `BlockRegistry`).

        Returns:
            The registry.
        """
        return self._br

    def spawn(self) -> Pos:
        """Returns the spawn position (Go `Spawn`).

        Returns:
            The spawn position.
        """
        return self._set.spawn

    def time(self) -> Int64:
        """Returns the time of day in ticks (Go `Time`).

        Returns:
            The time.
        """
        return self._set.time

    def current_tick(self) -> Int64:
        """Returns the number of ticks the world has run.

        Returns:
            The tick count.
        """
        return self._set.current_tick

    def default_game_mode(self) -> GameMode:
        """Returns the game mode of new players (Go `DefaultGameMode`).

        Returns:
            The game mode.
        """
        return self._set.default_game_mode

    def difficulty(self) -> Int:
        """Returns the difficulty ID (Go `Difficulty`).

        Returns:
            The difficulty.
        """
        return self._set.difficulty

    def chunk_loaded(self, pos: ChunkPos) -> Bool:
        """Reports whether a chunk is in memory.

        Args:
            pos: The chunk position.

        Returns:
            True if the chunk was loaded or generated before.
        """
        return chunk_key(pos) in self._index

    def chunk(mut self, pos: ChunkPos) -> ref[self._chunks[0]] Chunk:
        """Returns a chunk, generating it on first use (Go `chunk`, with
        generation in place of the provider).

        Args:
            pos: The chunk position.

        Returns:
            The chunk.
        """
        var key = chunk_key(pos)
        var i = self._index.get(key)
        if case .Some(idx) = i:
            return self._chunks[idx]
        var c = Chunk(self._br, self._dim.range())
        self._gen.generate_chunk(pos, c)
        self._index[key] = len(self._chunks)
        self._chunks.append(c^)
        return self._chunks[len(self._chunks) - 1]

    def height_map(mut self, pos: ChunkPos) -> HeightMap:
        """Returns the height map of a chunk, generating the chunk on first
        use (Go `Column.HeightMap` through the world's registry).

        Args:
            pos: The chunk position.

        Returns:
            A copy of the height map.
        """
        _ = self.chunk(pos)
        var idx = self._index.get(chunk_key(pos)).value()
        return self._chunks[idx].height_map(self._br)

    def tick(mut self) -> Bool:
        """Runs one tick (Go `ticker.tick`): advances the time when the
        time cycle is on.

        Returns:
            True if viewers should be sent the time (every 20 ticks, as Go
            sends `ViewTime` once a second).
        """
        self._set.current_tick += 1
        if self._set.time_cycle:
            self._set.time += 1
        return self._set.current_tick % 20 == 0
