"""World configuration, ported from Dragonfly `server/world/conf.go`.

Go's `Config` holds interface values with nil defaults; here the generator
and provider are values of the types the world's `WorldTypes` names, and the
block registry is shared through an `ArcPointer`. Go's `Log` (errors go to
`World.last_error`), `PortalDestination`, `Entities` (the entity set is a
type) and `ChunkLoadWorkers` (chunks load on the loop) have no
counterpart.
"""

from std.memory import ArcPointer

from nethernet.os.random import fill_random

from .block_registry import BasicBlockRegistry
from .dimension import OVERWORLD, Dimension
from .item import ItemRegistry
from .world import World, WorldTypes


struct Config[T: WorldTypes](Movable):
    """The settings a world is created with (Go `Config`)."""

    var dim: Dimension
    """The dimension (Go default: the Overworld)."""
    var provider: Self.T.Provider
    """Loads and stores chunks and settings."""
    var generator: Self.T.Generator
    """Generates chunks the provider does not have."""
    var blocks: ArcPointer[BasicBlockRegistry]
    """The finalized block registry."""
    var items: ArcPointer[ItemRegistry]
    """The items block entities encode their contents with; empty by
    default, which drops container contents on save."""
    var read_only: Bool
    """Never write to the provider."""
    var save_interval_ms: Int
    """How often to save (default 10 minutes); negative disables it."""
    var chunk_unload_interval_ms: Int
    """How often to unload unused chunks (default 2 minutes)."""
    var random_tick_speed: Int
    """Random ticks per sub-chunk per tick (default 3); -1 or lower
    disables them."""
    var seed: Optional[Tuple[UInt64, UInt64]]
    """The seeds of the world's generator; None draws them from the
    operating system (Go seeds from the clock)."""
    var synchronous: Bool
    """Tick without viewers and tick every loaded chunk (Go
    `Synchronous`); for tests driven by `advance_tick`."""

    def __init__(
        out self,
        var generator: Self.T.Generator,
        var provider: Self.T.Provider,
        blocks: ArcPointer[BasicBlockRegistry],
    ):
        """Creates a configuration with Go's defaults."""
        self.dim = OVERWORLD
        self.provider = provider^
        self.generator = generator^
        self.blocks = blocks
        self.items = ArcPointer(ItemRegistry())
        self.read_only = False
        self.save_interval_ms = 10 * 60 * 1000
        self.chunk_unload_interval_ms = 2 * 60 * 1000
        self.random_tick_speed = 3
        self.seed = None
        self.synchronous = False

    def new(deinit self, now_ms: Int) raises -> World[Self.T]:
        """Creates the world (Go `Config.New`). It runs its first tick at
        once and is then driven by `World.tick`."""
        var seed: Tuple[UInt64, UInt64]
        if case .Some(s) = self.seed:
            seed = s
        else:
            var b = List[UInt8](length=16, fill=0)
            fill_random(Span(b))
            var a = UInt64(0)
            var c = UInt64(0)
            for i in range(8):
                a = (a << 8) | UInt64(b[i])
                c = (c << 8) | UInt64(b[8 + i])
            seed = (a, c)
        var save = self.save_interval_ms
        if save == 0:
            save = 10 * 60 * 1000
        var unload = self.chunk_unload_interval_ms
        if unload <= 0:
            unload = 2 * 60 * 1000
        var speed = self.random_tick_speed
        if speed == 0:
            speed = 3
        return World[Self.T](
            self.dim,
            self.generator^,
            self.provider^,
            self.blocks,
            self.items,
            self.read_only,
            save,
            unload,
            speed,
            seed,
            self.synchronous,
            now_ms,
        )
