"""The world, ported from Dragonfly `server/world/world.go`, with the methods
of Go's `Tx` (`tx.go`), `ticker` (`tick.go`), `Loader` (`loader.go`) and
`weather` (`weather.go`).

A `World` owns its chunks, entities, loaders and settings, and is driven by
the server's single-threaded loop: sessions call its methods while handling
packets, and the loop calls `tick(now_ms)` to run the 20 ticks per second.
Go's `World.Exec(func(tx *Tx))` becomes a direct call, and `Tx` is an alias
of `World` (`tx.mojo`).

The world is generic over a `WorldTypes`, which names its generator,
provider, viewer, handler, block set and entity set at compile time (Mojo
has no interface values). Blocks are runtime IDs; entities are
`EntityHandle`s owned by the world and addressed by UUID; loaders are owned
by the world and addressed by `LoaderID` (see `loader.mojo`).

Durations are milliseconds (Go `time.Duration`); world ticks are 50 ms.

Light is computed as Dragonfly does when a chunk loads (`Fill` for the
chunk, then `Spread` for every loaded chunk whose 3x3 neighbourhood it
completes; see `chunk/light_area.mojo`). Dragonfly never relights after
that, so its light goes stale when blocks change; Ignis relights around
every changed block (`chunk.light.relight`), giving what Dragonfly computes
when the chunks are loaded again.

Fixed from Dragonfly: chunks holding entities are always saved, and an
entity changing chunk marks both chunks modified (Dragonfly lost entities
that moved into an unmodified chunk and saved stale positions).

Blocks drop items through `drop_item`, which queues them for the world's
owner (`take_item_drops`): item entities need the item registry.

Not ported yet: block entities, redstone, structures, lightning, sleeping,
view layers and portals. Errors Go logs (provider failures) are kept in
`last_error` instead.
"""

from std.collections import Dict, Set
from std.memory import ArcPointer

from minecraft.protocol.uuid import UUID
from nethernet.os.random import fill_random

from ..block.cube.bbox import BBox
from ..block.cube.face import Face
from ..block.cube.pos import Pos
from ..block.cube.range import Range
from ..block.cube.rotation import Rotation
from ..internal.rand import Rand
from ..mgl64 import Vec3
from ..block.hash import AnyBlock
from ..item.stack import Stack
from .block import Block, LiquidInfo
from .block_registry import BasicBlockRegistry
from .block_set import BlockTypes
from .block_source import BlockSource
from .chunk.chunk import Chunk
from .chunk.column import (
    Column as ChunkColumn,
    Entity as ChunkEntity,
    ScheduledBlockUpdate,
)
from .chunk.light import relight
from .chunk.light_area import ChunkPointer, LightArea, chunk_pointer
from .difficulty import Difficulty
from .dimension import Dimension, END, NETHER, OVERWORLD
from .entity import EntityHandle, EntityTypes
from .game_mode import GameMode
from .generator import Generator
from .handler import Handler
from .loader import Loader, LoaderID
from .position import ChunkPos, chunk_pos_from_block_pos, chunk_pos_from_vec3
from .provider import Provider, uuid_key
from .settings import Settings, default_settings
from .tick import (
    NeighbourUpdate,
    RandUint4,
    ScheduledTick,
    ScheduledTickQueue,
    any_within_distance,
)
from .particle import Particle
from .sound import Sound
from .tx import Context, SetOpts
from .viewer import Viewer
from .weather import advance_weather, set_raining, set_thunder

comptime TICK_MS = 50
"""The length of a world tick (Go `time.Second / 20`)."""

comptime _MAX_CATCH_UP = 10


trait WorldTypes:
    """The types a world is built from, chosen at compile time.

    ```mojo
    struct ServerWorld(WorldTypes):
        comptime Generator = Flat
        comptime Provider = MemoryProvider
        comptime Viewer = SessionViewer
        comptime Handler = NopHandler
        comptime Blocks = VanillaBlocks
        comptime Entities = VanillaEntities
    ```
    """

    comptime Generator: Generator
    """Generates chunks the provider does not have."""
    comptime Provider: Provider
    """Loads and stores chunks and settings."""
    comptime Viewer: Viewer
    """What loaders show the world to (a session's viewer)."""
    comptime Handler: Handler
    """Handles world events."""
    comptime Blocks: BlockTypes
    """The block types; dispatches scheduled, random and neighbour ticks."""
    comptime Entities: EntityTypes
    """The entity types; the state of every entity is an
    `Entities.State`."""


@fieldwise_init
struct ItemDrop(Copyable):
    """A stack dropped by a block, waiting to become an item entity."""

    var pos: Vec3
    """Where the item appears (Go passes `pos.Vec3Centre()`)."""
    var stack: Stack
    """The stack."""


struct Column(Movable):
    """A loaded chunk with its entities and viewers (Go `world.Column`)."""

    var pos: ChunkPos
    """The chunk's position."""
    var modified: Bool
    """Whether the chunk changed since it was loaded or saved."""
    var chunk: Chunk
    """The blocks and biomes."""
    var entities: List[UInt128]
    """The keys (`uuid_key`) of the entities in the chunk."""
    var viewers: List[LoaderID]
    """The loaders viewing the chunk (Go keeps viewers and loaders)."""
    var broken: Bool
    """The provider failed to load the chunk; it is empty and never saved
    (Go hands out an unregistered empty column instead)."""

    def __init__(out self, pos: ChunkPos, var chunk: Chunk):
        """Creates a column without entities or viewers."""
        self.pos = pos
        self.modified = False
        self.chunk = chunk^
        self.entities = List[UInt128]()
        self.viewers = List[LoaderID]()
        self.broken = False


struct _EntityEntry[E: EntityTypes](Copyable):
    var handle: EntityHandle[Self.E]
    var chunk: ChunkPos
    """The chunk the entity was last registered in (Go `w.entities`)."""

    def __init__(out self, var handle: EntityHandle[Self.E], chunk: ChunkPos):
        self.handle = handle^
        self.chunk = chunk

    def into_handle(deinit self) -> EntityHandle[Self.E]:
        return self.handle^


struct World[T: WorldTypes](Movable):
    """A Minecraft world: chunks, entities, viewers, time and weather (Go
    `World`)."""

    var _dim: Dimension
    var _ra: Range
    var _read_only: Bool
    var _random_tick_speed: Int
    var _synchronous: Bool
    var _save_interval_ms: Int
    var _chunk_unload_interval_ms: Int
    var _br: ArcPointer[BasicBlockRegistry]
    var _generator: Self.T.Generator
    var _provider: Self.T.Provider
    var _handler: Optional[Self.T.Handler]
    var _set: Settings
    var _r: Rand
    var _global_r: Rand
    var _cols: List[Column]
    var _col_index: Dict[ChunkPos, Int]
    var _ents: List[_EntityEntry[Self.T.Entities]]
    var _ent_index: Dict[UInt128, Int]
    var _scheduled: ScheduledTickQueue
    var _neighbour_updates: List[NeighbourUpdate]
    var _item_drops: List[ItemDrop]
    var _loaders: List[Optional[Loader[Self.T.Viewer]]]
    var _loader_gens: List[UInt32]
    var _free_loaders: List[Int]
    var _viewer_count: Int
    var _next_tick_ms: Int
    var _next_unload_ms: Int
    var _next_save_ms: Int
    var _ticking: Optional[UInt128]
    var _ticking_removed: Bool
    var _closed: Bool
    var last_error: Optional[String]
    """The last provider error, which Go would log."""

    def __init__(
        out self,
        dim: Dimension,
        var generator: Self.T.Generator,
        var provider: Self.T.Provider,
        blocks: ArcPointer[BasicBlockRegistry],
        read_only: Bool,
        save_interval_ms: Int,
        chunk_unload_interval_ms: Int,
        random_tick_speed: Int,
        seed: Tuple[UInt64, UInt64],
        synchronous: Bool,
        now_ms: Int,
    ):
        """Creates a world and runs its first tick (Go `Config.New`). Use
        `Config.new`, which fills in the defaults."""
        var r = Rand(seed[0], seed[1])
        var s: Settings
        if case .Some(ref saved) = provider.settings():
            s = saved.copy()
        else:
            # Go draws these from the global source, so the world's own
            # generator starts in step with Dragonfly's seeded one.
            var sr = Rand(seed[0] ^ 0x9E3779B97F4A7C15, seed[1])
            s = default_settings(sr)
            s.spawn = generator.default_spawn(dim)
        self._dim = dim
        self._ra = dim.range()
        self._read_only = read_only
        self._random_tick_speed = random_tick_speed
        self._synchronous = synchronous
        self._save_interval_ms = save_interval_ms
        self._chunk_unload_interval_ms = chunk_unload_interval_ms
        self._br = blocks
        self._generator = generator^
        self._provider = provider^
        self._handler = None
        self._scheduled = ScheduledTickQueue(s.current_tick)
        self._set = s^
        self._r = r^
        self._global_r = Rand(seed[1] ^ 0x5851F42D4C957F2D, seed[0])
        self._cols = List[Column]()
        self._col_index = Dict[ChunkPos, Int]()
        self._ents = List[_EntityEntry[Self.T.Entities]]()
        self._ent_index = Dict[UInt128, Int]()
        self._neighbour_updates = List[NeighbourUpdate]()
        self._item_drops = List[ItemDrop]()
        self._loaders = List[Optional[Loader[Self.T.Viewer]]]()
        self._loader_gens = List[UInt32]()
        self._free_loaders = List[Int]()
        self._viewer_count = 0
        self._next_tick_ms = now_ms + TICK_MS
        self._next_unload_ms = now_ms + chunk_unload_interval_ms
        self._next_save_ms = now_ms + save_interval_ms
        self._ticking = None
        self._ticking_removed = False
        self._closed = False
        self.last_error = None
        self.advance_tick()

    # ===------------------------------------------------------------------=== #
    # Properties
    # ===------------------------------------------------------------------=== #

    def name(self) -> String:
        """Returns the display name of the world (Go `Name`)."""
        return self._set.name

    def dimension(self) -> Dimension:
        """Returns the world's dimension (Go `Dimension`)."""
        return self._dim

    def range(self) -> Range:
        """Returns the world's height range (Go `Range`)."""
        return self._ra

    def block_registry(self) -> ArcPointer[BasicBlockRegistry]:
        """Returns the block registry (Go `BlockRegistry`)."""
        return self._br

    def settings(ref self) -> ref[self._set] Settings:
        """Returns the world's settings."""
        return self._set

    def rand(mut self) -> ref[self._r] Rand:
        """Returns the world's random generator (Go passes it to random and
        scheduled ticks)."""
        return self._r

    def global_rand(mut self) -> ref[self._global_r] Rand:
        """Returns a generator standing in for Go's global `math/rand`
        source, which Dragonfly's blocks use for drops, bone meal and the
        like. It is separate from `rand`, so those draws leave the world's
        generator in step with Dragonfly's."""
        return self._global_r

    def current_tick(self) -> Int64:
        """Returns the world's tick counter (Go `Tx.CurrentTick`)."""
        return self._set.current_tick

    def handler(ref self) -> ref[self._handler] Optional[Self.T.Handler]:
        """Returns the world's event handler."""
        return self._handler

    def handle(mut self, var h: Self.T.Handler):
        """Sets the world's event handler (Go `Handle`)."""
        self._handler = h^

    def source(mut self) -> WorldSource[origin_of(self), Self.T]:
        """Returns the world as a `BlockSource` (Go: `*Tx` is a
        `BlockSource`), for block models.

        `World` cannot conform itself: `BlockSource.block` reads through an
        immutable reference, while `World.block` loads or generates missing
        chunks, as Go's `Tx.Block` does, and so needs a mutable one. The view
        holds a pointer to the world and loads chunks the same way. Use it
        for the duration of a call:
        `model.face_solid(pos, Face.UP, tx.source())`.
        """
        return WorldSource(Pointer(to=self))

    # ===------------------------------------------------------------------=== #
    # Blocks (Go Tx)
    # ===------------------------------------------------------------------=== #

    def block(mut self, pos: Pos) -> UInt32:
        """Returns the block at a position, loading or generating its chunk
        if needed (Go `Tx.Block`)."""
        if pos.out_of_bounds(self._ra):
            return self._br[].air_runtime_id()
        var ci = self._chunk(chunk_pos_from_block_pos(pos))
        return self._cols[ci].chunk.block(
            UInt8(pos.x() & 0xF), Int16(pos.y()), UInt8(pos.z() & 0xF), 0
        )

    def block_as[B: Block](mut self, pos: Pos) -> Optional[B]:
        """Returns the block at a position as a `B` (Go
        `tx.Block(pos).(B)`)."""
        var rid = self.block(pos)
        return self._br[].block[B](rid)

    def block_loaded(self, pos: Pos) -> Optional[UInt32]:
        """Returns the block at a position only if its chunk is loaded (Go
        `Tx.BlockLoaded`)."""
        if pos.out_of_bounds(self._ra):
            return None
        if case .Some(ci) = self._col_index.get(chunk_pos_from_block_pos(pos)):
            return self._cols[ci].chunk.block(
                UInt8(pos.x() & 0xF), Int16(pos.y()), UInt8(pos.z() & 0xF), 0
            )
        return None

    def set_block[
        B: Block
    ](mut self, pos: Pos, b: B, opts: SetOpts = SetOpts()):
        """Sets a block (Go `Tx.SetBlock`)."""
        self.set_block_runtime_id(pos, self._br[].block_runtime_id(b), opts)

    def set_block_runtime_id(
        mut self, pos: Pos, rid: UInt32, opts: SetOpts = SetOpts()
    ):
        """Sets a block given its runtime ID (Go `Tx.SetBlock`): viewers of
        the chunk see the change, a liquid on layer 1 is kept consistent,
        and the block and its neighbours get a neighbour update next tick."""
        if pos.out_of_bounds(self._ra):
            return
        var x = UInt8(pos.x() & 0xF)
        var y = Int16(pos.y())
        var z = UInt8(pos.z() & 0xF)
        var ci = self._chunk(chunk_pos_from_block_pos(pos))
        var air = self._br[].air_runtime_id()
        var before = air
        if rid != air and not opts.disable_liquid_displacement:
            before = self._cols[ci].chunk.block(x, y, z, 0)
        var old_light = self._light_info(ci, x, y, z)
        var old_height = self._cols[ci].chunk.height_at(self._br[], x, z)
        self._cols[ci].modified = True
        self._cols[ci].chunk.set_block(x, y, z, 0, rid)

        var shown = rid
        if not opts.disable_liquid_displacement:
            var second_layer = False
            var second = air
            var li = self._cols[ci].chunk.block(x, y, z, 1)
            if rid == air:
                if li != air:
                    # Removing a block leaves the liquid inside it.
                    self._cols[ci].chunk.set_block(x, y, z, 0, li)
                    self._cols[ci].chunk.set_block(x, y, z, 1, air)
                    second_layer = True
                    shown = li
            elif self._br[].liquid_displacing_block(rid):
                if before != air and self._br[].liquid_block(before):
                    var l = AnyBlock(
                        kind=self._br[].kind(before),
                        state=self._br[].state_hash(before),
                    )
                    if Self.T.Blocks.can_displace(
                        self._br[].kind(rid), self._br[].state_hash(rid), l
                    ):
                        self._cols[ci].chunk.set_block(x, y, z, 1, before)
                        second_layer = True
                        second = before
            elif li != air:
                self._cols[ci].chunk.set_block(x, y, z, 1, air)
                second_layer = True
            if second_layer:
                self._notify_block(ci, pos, second, 1)
        self._cols[ci].chunk.update_height_map_column(self._br[], x, z)
        var height = self._cols[ci].chunk.height_at(self._br[], x, z)
        if height != old_height or self._light_info(ci, x, y, z) != old_light:
            self._relight(ci, pos, Int(old_height))
        self._notify_block(ci, pos, shown, 0)
        if not opts.disable_block_updates:
            self._do_block_updates_around(pos)

    def _light_info(self, ci: Int, x: UInt8, y: Int16, z: UInt8) -> Int:
        # The light emitted and filtered at a position (the higher of both
        # layers), which with the height map is all light depends on.
        ref c = self._cols[ci].chunk
        var a = c.block(x, y, z, 0)
        var b = c.block(x, y, z, 1)
        var emission = max(self._br[].light_block(a), self._br[].light_block(b))
        var filter = max(
            self._br[].filtering_block(a), self._br[].filtering_block(b)
        )
        return (Int(emission) << 4) | Int(filter)

    def _relight(mut self, ci: Int, pos: Pos, old_height: Int):
        # Relights the 3x3 chunks around a changed block; chunks that are
        # not loaded are left out.
        var centre = self._cols[ci].pos
        var ptrs = List[ChunkPointer](capacity=9)
        var absent = List[Int]()
        for dz in range(-1, 2):
            for dx in range(-1, 2):
                var p = ChunkPos(centre.x() + Int32(dx), centre.z() + Int32(dz))
                var j = self._col_index.get(p).or_else(-1)
                if j < 0:
                    absent.append(len(ptrs))
                    j = ci
                ptrs.append(chunk_pointer(self._cols[j].chunk))
        var a = LightArea(
            self._br[], ptrs^, Int(centre.x()) - 1, Int(centre.z()) - 1
        )
        for i in absent:
            a.set_absent(i)
        relight(a, pos.x(), pos.y(), pos.z(), old_height)

    def light(self, pos: Pos) -> UInt8:
        """Returns the higher of the sky and block light at a position, 0 to
        15; 0 in chunks that are not loaded (Go `Tx.Light`)."""
        if pos.y() < self._ra.min():
            return 0
        if pos.y() > self._ra.max():
            # Above the rest of the world, so full sky light.
            return 15
        if case .Some(ci) = self._col_index.get(chunk_pos_from_block_pos(pos)):
            return self._cols[ci].chunk.light(
                UInt8(pos.x() & 0xF), Int16(pos.y()), UInt8(pos.z() & 0xF)
            )
        return 0

    def sky_light(mut self, pos: Pos) -> UInt8:
        """Returns the sky light at a position, 0 to 15, loading or
        generating its chunk if needed (Go `Tx.SkyLight`)."""
        if pos.y() < self._ra.min():
            return 0
        if pos.y() > self._ra.max():
            return 15
        var ci = self._chunk(chunk_pos_from_block_pos(pos))
        return self._cols[ci].chunk.sky_light(
            UInt8(pos.x() & 0xF), Int16(pos.y()), UInt8(pos.z() & 0xF)
        )

    def block_light(mut self, pos: Pos) -> UInt8:
        """Returns the light from light-emitting blocks at a position, 0 to
        15, loading or generating its chunk if needed (Go
        `Tx.BlockLight`)."""
        if pos.out_of_bounds(self._ra):
            return 0
        var ci = self._chunk(chunk_pos_from_block_pos(pos))
        return self._cols[ci].chunk.block_light(
            UInt8(pos.x() & 0xF), Int16(pos.y()), UInt8(pos.z() & 0xF)
        )

    def _notify_block(mut self, ci: Int, pos: Pos, rid: UInt32, layer: Int):
        var ids = self._cols[ci].viewers.copy()
        for id in ids:
            self._loader(id).viewer.view_block_update(pos, rid, layer)

    def biome(mut self, pos: Pos) -> Int:
        """Returns the biome ID at a position (Go `Tx.Biome`)."""
        if pos.out_of_bounds(self._ra):
            return 0
        var ci = self._chunk(chunk_pos_from_block_pos(pos))
        return Int(
            self._cols[ci].chunk.biome(
                UInt8(pos.x() & 0xF), Int16(pos.y()), UInt8(pos.z() & 0xF)
            )
        )

    def set_biome(mut self, pos: Pos, biome: Int):
        """Sets the biome ID at a position (Go `Tx.SetBiome`)."""
        if pos.out_of_bounds(self._ra):
            return
        var ci = self._chunk(chunk_pos_from_block_pos(pos))
        self._cols[ci].modified = True
        self._cols[ci].chunk.set_biome(
            UInt8(pos.x() & 0xF),
            Int16(pos.y()),
            UInt8(pos.z() & 0xF),
            UInt32(biome),
        )

    def highest_block(mut self, x: Int, z: Int) -> Int:
        """Returns the Y of the highest non-air block in a column (Go
        `Tx.HighestBlock`)."""
        var ci = self._chunk(ChunkPos(Int32(x >> 4), Int32(z >> 4)))
        return Int(
            self._cols[ci].chunk.highest_block(UInt8(x & 0xF), UInt8(z & 0xF))
        )

    def highest_obstructing_block(mut self, x: Int, z: Int) -> Int:
        """Returns the Y of the highest block in a column with a solid top
        or bottom face (Go `Tx.highestObstructingBlock`)."""
        var y = self.highest_block(x, z)
        while y >= self._ra.min():
            var pos = Pos(x, y, z)
            var rid = self.block(pos)
            var kind = self._br[].kind(rid)
            var hash = self._br[].state_hash(rid)
            if Self.T.Blocks.face_solid(
                kind, hash, pos, Face.UP, self.source()
            ) or Self.T.Blocks.face_solid(
                kind, hash, pos, Face.DOWN, self.source()
            ):
                return y
            y -= 1
        return self._ra.min()

    def highest_light_blocker(mut self, x: Int, z: Int) -> Int:
        """Returns the Y of the highest fully light-blocking block in a
        column (Go `Tx.HighestLightBlocker`)."""
        var ci = self._chunk(ChunkPos(Int32(x >> 4), Int32(z >> 4)))
        return Int(
            self._cols[ci].chunk.highest_light_blocker(
                self._br[], UInt8(x & 0xF), UInt8(z & 0xF)
            )
        )

    def schedule_block_update[
        B: Block
    ](mut self, pos: Pos, b: B, delay_ms: Int):
        """Schedules an update for a block at a position (Go
        `Tx.ScheduleBlockUpdate`)."""
        self.schedule_block_update_runtime_id(
            pos, self._br[].block_runtime_id(b), delay_ms
        )

    def schedule_block_update_runtime_id(
        mut self, pos: Pos, rid: UInt32, delay_ms: Int
    ):
        """Schedules an update for a block given its runtime ID. An update
        for the same position and block that is due later wins."""
        if pos.out_of_bounds(self._ra):
            return
        self._scheduled.schedule(pos, rid, self._block_hash(rid), delay_ms)

    def scheduled_updates(self) -> List[ScheduledTick]:
        """Returns the pending scheduled block updates."""
        return self._scheduled.ticks.copy()

    def _block_hash(self, rid: UInt32) -> UInt64:
        # Go `BlockHash`: the type's base hash and the state hash.
        ref br = self._br[]
        return br.kind(rid) | (br.state_hash(rid) << UInt64(br.bit_size()))

    def _do_block_updates_around(mut self, pos: Pos):
        # Go `doBlockUpdatesAround`.
        if pos.out_of_bounds(self._ra):
            return
        self._neighbour_updates.append(NeighbourUpdate(pos, pos))
        for n in pos.neighbours(self._ra):
            self._neighbour_updates.append(NeighbourUpdate(n, pos))

    # ===------------------------------------------------------------------=== #
    # Liquids (Go Tx.Liquid, Tx.SetLiquid)
    # ===------------------------------------------------------------------=== #

    def liquid(mut self, pos: Pos) -> Optional[UInt32]:
        """Returns the liquid at a position, on either layer (Go
        `Tx.Liquid`)."""
        if pos.out_of_bounds(self._ra):
            return None
        var ci = self._chunk(chunk_pos_from_block_pos(pos))
        var x = UInt8(pos.x() & 0xF)
        var y = Int16(pos.y())
        var z = UInt8(pos.z() & 0xF)
        var rid = self._cols[ci].chunk.block(x, y, z, 0)
        if self._br[].liquid_block(rid):
            return rid
        rid = self._cols[ci].chunk.block(x, y, z, 1)
        if self._br[].liquid_block(rid):
            return rid
        return None

    def liquid_info(mut self, pos: Pos) -> Optional[LiquidInfo]:
        """Returns the `Liquid` methods of the liquid at a position."""
        if case .Some(rid) = self.liquid(pos):
            return Self.T.Blocks.liquid_info(
                self._br[].kind(rid), self._br[].state_hash(rid)
            )
        return None

    def set_liquid[B: Block](mut self, pos: Pos, b: B):
        """Sets a liquid at a position (Go `Tx.SetLiquid`)."""
        self.set_liquid_runtime_id(pos, self._br[].block_runtime_id(b))

    def set_liquid_runtime_id(mut self, pos: Pos, rid: UInt32):
        """Sets a liquid given its runtime ID (Go `Tx.SetLiquid`): it shares
        the position with the block there if that block is replaceable by
        it or can displace it, and replaces any liquid already there."""
        if pos.out_of_bounds(self._ra):
            return
        var ci = self._chunk(chunk_pos_from_block_pos(pos))
        var x = UInt8(pos.x() & 0xF)
        var y = Int16(pos.y())
        var z = UInt8(pos.z() & 0xF)
        var cur = self._cols[ci].chunk.block(x, y, z, 0)
        var kind = self._br[].kind(cur)
        var hash = self._br[].state_hash(cur)
        var l = AnyBlock(
            kind=self._br[].kind(rid), state=self._br[].state_hash(rid)
        )
        if not Self.T.Blocks.replaceable_by(kind, hash, l):
            if not self._br[].liquid_displacing_block(
                cur
            ) or not Self.T.Blocks.can_displace(kind, hash, l):
                return
        var old_light = self._light_info(ci, x, y, z)
        var old_height = self._cols[ci].chunk.height_at(self._br[], x, z)
        if self._remove_liquids(ci, pos):
            self._cols[ci].chunk.set_block(x, y, z, 0, rid)
            self._notify_block(ci, pos, rid, 0)
        else:
            self._cols[ci].chunk.set_block(x, y, z, 1, rid)
            self._notify_block(ci, pos, rid, 1)
        self._cols[ci].modified = True
        self._relight_if_changed(ci, pos, old_light, old_height)
        self._do_block_updates_around(pos)

    def remove_liquid(mut self, pos: Pos):
        """Removes any liquid at a position (Go `Tx.SetLiquid(pos, nil)`)."""
        if pos.out_of_bounds(self._ra):
            return
        var ci = self._chunk(chunk_pos_from_block_pos(pos))
        var x = UInt8(pos.x() & 0xF)
        var y = Int16(pos.y())
        var z = UInt8(pos.z() & 0xF)
        var old_light = self._light_info(ci, x, y, z)
        var old_height = self._cols[ci].chunk.height_at(self._br[], x, z)
        _ = self._remove_liquids(ci, pos)
        self._relight_if_changed(ci, pos, old_light, old_height)
        self._do_block_updates_around(pos)

    def _relight_if_changed(
        mut self, ci: Int, pos: Pos, old_light: Int, old_height: Int16
    ):
        # Liquids change the light filtered at their position like blocks
        # do in `set_block_runtime_id`.
        var x = UInt8(pos.x() & 0xF)
        var y = Int16(pos.y())
        var z = UInt8(pos.z() & 0xF)
        self._cols[ci].chunk.update_height_map_column(self._br[], x, z)
        var height = self._cols[ci].chunk.height_at(self._br[], x, z)
        if height != old_height or self._light_info(ci, x, y, z) != old_light:
            self._relight(ci, pos, Int(old_height))

    def _remove_liquids(mut self, ci: Int, pos: Pos) -> Bool:
        # Go `removeLiquids`: True if layer 0 is left empty.
        var air = self._br[].air_runtime_id()
        var x = UInt8(pos.x() & 0xF)
        var y = Int16(pos.y())
        var z = UInt8(pos.z() & 0xF)
        var none_left = False
        var l0 = self._cols[ci].chunk.block(x, y, z, 0)
        if self._br[].liquid_block(l0):
            self._cols[ci].chunk.set_block(x, y, z, 0, air)
            self._notify_block(ci, pos, air, 0)
            none_left = True
        elif l0 == air:
            none_left = True
        var l1 = self._cols[ci].chunk.block(x, y, z, 1)
        if self._br[].liquid_block(l1):
            self._cols[ci].chunk.set_block(x, y, z, 1, air)
            self._notify_block(ci, pos, air, 1)
        return none_left

    # ===------------------------------------------------------------------=== #
    # Handler events, sounds, particles and item drops
    # ===------------------------------------------------------------------=== #

    def handle_liquid_flow(
        mut self,
        mut ctx: Context,
        from_: Pos,
        into: Pos,
        liquid: AnyBlock,
        replaced: AnyBlock,
    ):
        """Calls the handler's `handle_liquid_flow`."""
        if self._handler:
            var h = self._handler.take()
            h.handle_liquid_flow(self, ctx, from_, into, liquid, replaced)
            self._handler = h^

    def handle_liquid_decay(
        mut self,
        mut ctx: Context,
        pos: Pos,
        before: AnyBlock,
        after: Optional[AnyBlock],
    ):
        """Calls the handler's `handle_liquid_decay`."""
        if self._handler:
            var h = self._handler.take()
            h.handle_liquid_decay(self, ctx, pos, before, after)
            self._handler = h^

    def handle_liquid_harden(
        mut self,
        mut ctx: Context,
        hardened_pos: Pos,
        liquid_hardened: AnyBlock,
        other_liquid: AnyBlock,
        new_block: AnyBlock,
    ):
        """Calls the handler's `handle_liquid_harden`."""
        if self._handler:
            var h = self._handler.take()
            h.handle_liquid_harden(
                self,
                ctx,
                hardened_pos,
                liquid_hardened,
                other_liquid,
                new_block,
            )
            self._handler = h^

    def handle_leaves_decay(mut self, mut ctx: Context, pos: Pos):
        """Calls the handler's `handle_leaves_decay`."""
        if self._handler:
            var h = self._handler.take()
            h.handle_leaves_decay(self, ctx, pos)
            self._handler = h^

    def handle_fire_spread(mut self, mut ctx: Context, from_: Pos, to: Pos):
        """Calls the handler's `handle_fire_spread`."""
        if self._handler:
            var h = self._handler.take()
            h.handle_fire_spread(self, ctx, from_, to)
            self._handler = h^

    def handle_block_burn(mut self, mut ctx: Context, pos: Pos):
        """Calls the handler's `handle_block_burn`."""
        if self._handler:
            var h = self._handler.take()
            h.handle_block_burn(self, ctx, pos)
            self._handler = h^

    def handle_crop_trample(mut self, mut ctx: Context, pos: Pos):
        """Calls the handler's `handle_crop_trample`."""
        if self._handler:
            var h = self._handler.take()
            h.handle_crop_trample(self, ctx, pos)
            self._handler = h^

    def handle_explosion(
        mut self,
        mut ctx: Context,
        src: Vec3,
        size: Float64,
        mut entities: List[UUID],
        mut blocks: List[Pos],
        mut item_drop_chance: Float64,
        mut spawn_fire: Bool,
    ):
        """Calls the handler's `handle_explosion`."""
        if self._handler:
            var h = self._handler.take()
            h.handle_explosion(
                self,
                ctx,
                src,
                size,
                entities,
                blocks,
                item_drop_chance,
                spawn_fire,
            )
            self._handler = h^

    def play_sound[S: Sound](mut self, pos: Vec3, s: S):
        """Plays a sound to the viewers of a position (Go `Tx.PlaySound`;
        the `HandleSound` event is not ported)."""
        for id in self.viewers(pos):
            self._loader(id).viewer.view_sound(pos, s)

    def add_particle[P: Particle](mut self, pos: Vec3, p: P):
        """Shows a particle to the viewers of a position (Go
        `Tx.AddParticle`)."""
        for id in self.viewers(pos):
            self._loader(id).viewer.view_particle(pos, p)

    def drop_item(mut self, pos: Vec3, s: Stack):
        """Drops a stack as an item entity at a position (Go's `dropItem` in
        `block`). The world cannot build item entities itself (their NBT
        needs the item registry), so drops queue up until the owner of the
        world takes them with `take_item_drops` and spawns them."""
        if s.empty():
            return
        self._item_drops.append(ItemDrop(pos, s.copy()))

    def take_item_drops(mut self) -> List[ItemDrop]:
        """Returns and clears the queued item drops."""
        var out = self._item_drops^
        self._item_drops = List[ItemDrop]()
        return out^

    # ===------------------------------------------------------------------=== #
    # Time, weather, spawn and settings
    # ===------------------------------------------------------------------=== #

    def time(self) -> Int:
        """Returns the time of day (Go `Time`)."""
        return Int(self._set.time)

    def set_time(mut self, new: Int):
        """Sets the time of day, even while time is stopped (Go `SetTime`)."""
        self._set.time = Int64(new)
        for id in self.loaders():
            self._loader(id).viewer.view_time(new)

    def stop_time(mut self):
        """Stops the day/night cycle (Go `StopTime`)."""
        self._enable_time_cycle(False)

    def start_time(mut self):
        """Restarts the day/night cycle (Go `StartTime`)."""
        self._enable_time_cycle(True)

    def time_cycle(self) -> Bool:
        """Reports whether time advances (Go `TimeCycle`)."""
        return self._set.time_cycle

    def _enable_time_cycle(mut self, v: Bool):
        self._set.time_cycle = v
        for id in self.loaders():
            self._loader(id).viewer.view_time_cycle(v)

    def raining(self) -> Bool:
        """Reports whether it rains anywhere (Go `Tx.Raining`)."""
        return self._dim.weather_cycle() and self._set.raining

    def thundering(self) -> Bool:
        """Reports whether it thunders anywhere (Go `Tx.Thundering`)."""
        return self._dim.weather_cycle() and self._set.thundering

    def start_raining(mut self, duration_ms: Int):
        """Makes it rain for a duration (Go `StartRaining`)."""
        set_raining(self._set, True, duration_ms)

    def stop_raining(mut self):
        """Stops rain, and thunder with it (Go `StopRaining`)."""
        if self._set.raining:
            set_raining(self._set, False, (self._r.int_n(8400) + 600) * 1000)
            if self._set.thundering:
                set_thunder(
                    self._set, False, (self._r.int_n(8400) + 600) * 1000
                )

    def start_thundering(mut self, duration_ms: Int):
        """Makes it thunder and rain for a duration (Go
        `StartThundering`)."""
        set_thunder(self._set, True, duration_ms)
        set_raining(self._set, True, duration_ms)

    def stop_thundering(mut self):
        """Stops thunder (Go `StopThundering`)."""
        if self._set.thundering and self._set.raining:
            set_thunder(self._set, False, (self._r.int_n(8400) + 600) * 1000)

    def start_weather_cycle(mut self):
        """Lets the weather change by itself (Go `StartWeatherCycle`)."""
        self._set.weather_cycle = True

    def stop_weather_cycle(mut self):
        """Freezes the weather (Go `StopWeatherCycle`)."""
        self._set.weather_cycle = False

    def spawn(self) -> Pos:
        """Returns the world's spawn position (Go `Spawn`)."""
        if self._dim == END:
            return Pos(100, 50, 0)
        if self._dim == NETHER:
            return Pos(0, 0, 0)
        return self._set.spawn

    def set_spawn(mut self, pos: Pos):
        """Sets the spawn position; ignored in the Nether and End (Go
        `SetSpawn`)."""
        if self._dim == NETHER or self._dim == END:
            return
        self._set.spawn = pos
        for id in self.loaders():
            self._loader(id).viewer.view_world_spawn(pos)

    def player_spawn(mut self, id: UUID) -> Pos:
        """Returns a player's spawn position (Go `PlayerSpawn`)."""
        try:
            if case .Some(p) = self._provider.load_player_spawn_position(id):
                return p
        except e:
            self.last_error = String(t"load player spawn: {e}")
        return self.spawn()

    def set_player_spawn(mut self, id: UUID, pos: Pos):
        """Saves a player's spawn position (Go `SetPlayerSpawn`)."""
        try:
            self._provider.save_player_spawn_position(id, pos)
        except e:
            self.last_error = String(t"save player spawn: {e}")

    def default_game_mode(self) -> GameMode:
        """Returns the game mode of new players (Go `DefaultGameMode`)."""
        return self._set.default_game_mode

    def set_default_game_mode(mut self, mode: GameMode):
        """Sets the game mode of new players (Go `SetDefaultGameMode`)."""
        self._set.default_game_mode = mode

    def difficulty(self) -> Difficulty:
        """Returns the difficulty (Go `Difficulty`)."""
        return self._set.difficulty

    def set_difficulty(mut self, d: Difficulty):
        """Sets the difficulty (Go `SetDifficulty`)."""
        self._set.difficulty = d

    def set_tick_range(mut self, v: Int):
        """Sets the radius in chunks around viewers that is ticked (Go
        `SetTickRange`)."""
        self._set.tick_range = Int32(v)

    def set_required_sleep_duration(mut self, duration_ms: Int):
        """Sets how long players must sleep to skip the night (Go
        `SetRequiredSleepDuration`)."""
        self._set.required_sleep_ticks = Int64(duration_ms // TICK_MS)

    # ===------------------------------------------------------------------=== #
    # Entities
    # ===------------------------------------------------------------------=== #

    def add_entity(mut self, var e: EntityHandle[Self.T.Entities]) -> UUID:
        """Adds an entity at its position (Go `Tx.AddEntity`). Viewers of
        its chunk see it, and the handler's `handle_entity_spawn` runs."""
        var pos = e.data.pos
        return self.add_entity_at(e^, pos)

    def add_entity_at(
        mut self, var e: EntityHandle[Self.T.Entities], pos: Vec3
    ) -> UUID:
        """Adds an entity at a position (Go `Tx.AddEntityAt`)."""
        if e.id == UUID():
            e.id = self._new_entity_id()
        var key = uuid_key(e.id)
        if key in self._ent_index or self._ticking == key:
            return UUID()
        e.data.pos = pos
        var id = e.id
        var cp = chunk_pos_from_vec3(pos)
        var ci = self._chunk(cp)
        self._cols[ci].entities.append(key)
        self._cols[ci].modified = True
        var shown = e.copy()
        self._ent_index[key] = len(self._ents)
        self._ents.append(_EntityEntry(e^, cp))
        for v in self._cols[ci].viewers.copy():
            self._show_entity(v, shown)
        if self._handler:
            var h = self._handler.take()
            h.handle_entity_spawn(self, shown)
            self._handler = h^
        return id

    def remove_entity(
        mut self, id: UUID
    ) -> Optional[EntityHandle[Self.T.Entities]]:
        """Removes an entity (Go `Tx.RemoveEntity`): the handler's
        `handle_entity_despawn` runs and viewers stop seeing it.

        An entity that removes itself while it ticks is removed when its
        tick ends, and its handle is dropped.
        """
        var key = uuid_key(id)
        if self._ticking == key:
            self._ticking_removed = True
            return None
        if key not in self._ent_index:
            return None
        if self._handler:
            var shown = self._ents[
                self._ent_index.get(key).value()
            ].handle.copy()
            var h = self._handler.take()
            h.handle_entity_despawn(self, shown)
            self._handler = h^
        # The handler may have removed it already.
        if key not in self._ent_index:
            return None
        var entry = self._take_entity(key)
        self._unlink_entity(key, entry.chunk, entry.handle)
        return entry^.into_handle()

    def _unlink_entity(
        mut self,
        key: UInt128,
        cp: ChunkPos,
        e: EntityHandle[Self.T.Entities],
    ):
        if case .Some(ci) = self._col_index.get(cp):
            _remove_key(self._cols[ci].entities, key)
            self._cols[ci].modified = True
            for v in self._cols[ci].viewers.copy():
                self._loader(v).viewer.hide_entity(e)

    def _take_entity(mut self, key: UInt128) -> _EntityEntry[Self.T.Entities]:
        # Swap-removes an entry from the slab; the key must be present.
        var i = self._ent_index.pop(key, -1)
        var last = len(self._ents) - 1
        if i != last:
            self._ents.swap_elements(i, last)
            self._ent_index[uuid_key(self._ents[i].handle.id)] = i
        return self._ents.pop()

    def _new_entity_id(mut self) -> UUID:
        # Go: uuid.New() with the first 8 bytes cleared.
        var bytes = List[UInt8](length=16, fill=0)
        var v = self._r.uint64()
        for i in range(8):
            bytes[8 + i] = UInt8((v >> UInt64(8 * i)) & 0xFF)
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        try:
            return UUID(Span(bytes))
        except:
            return UUID()

    def explode_entity(mut self, id: UUID, src: Vec3, impact: Float64):
        """Applies an explosion at `src` to an entity (Go
        `ExplodableEntity.Explode`), removing it if it is destroyed."""
        if case .Some(i) = self._ent_index.get(uuid_key(id)):
            ref h = self._ents[i].handle
            if Self.T.Entities.explode(h.state, h.data, src, impact):
                _ = self.remove_entity(id)

    def has_entity(self, id: UUID) -> Bool:
        """Reports whether an entity is in the world."""
        return uuid_key(id) in self._ent_index

    def entity(self, id: UUID) -> Optional[EntityHandle[Self.T.Entities]]:
        """Returns a copy of an entity (Go `EntityHandle.Entity(tx)`)."""
        if case .Some(i) = self._ent_index.get(uuid_key(id)):
            return self._ents[i].handle.copy()
        return None

    def entity_count(self) -> Int:
        """Returns the number of entities in the world."""
        return len(self._ents)

    def entities(self) -> List[UUID]:
        """Returns the UUIDs of every entity (Go `Tx.Entities`)."""
        var out = List[UUID](capacity=len(self._ents))
        for ref e in self._ents:
            out.append(e.handle.id)
        return out^

    def players(self) -> List[UUID]:
        """Returns the UUIDs of every player entity (Go `Tx.Players`)."""
        var out = List[UUID]()
        for ref e in self._ents:
            if e.handle.identifier() == "minecraft:player":
                out.append(e.handle.id)
        return out^

    def entities_within(self, box: BBox) -> List[UUID]:
        """Returns the entities whose position is inside a box, in loaded
        chunks (Go `Tx.EntitiesWithin`)."""
        var out = List[UUID]()
        var lo = chunk_pos_from_vec3(box.min())
        var hi = chunk_pos_from_vec3(box.max())
        for x in range(lo.x(), hi.x() + 1):
            for z in range(lo.z(), hi.z() + 1):
                if case .Some(ci) = self._col_index.get(ChunkPos(x, z)):
                    for key in self._cols[ci].entities:
                        if case .Some(i) = self._ent_index.get(key):
                            if box.vec3_within(self._ents[i].handle.data.pos):
                                out.append(self._ents[i].handle.id)
        return out^

    def move_entity(
        mut self, id: UUID, pos: Vec3, rot: Rotation, on_ground: Bool
    ):
        """Moves an entity, showing the movement to the viewers of its chunk
        (what Go's entities do in `Move`). The entity changes chunk at the
        next tick."""
        if case .Some(i) = self._ent_index.get(uuid_key(id)):
            self._ents[i].handle.data.pos = pos
            self._ents[i].handle.data.rot = rot
            var e = self._ents[i].handle.copy()
            var cp = self._ents[i].chunk
            self.view_entity_movement(e, cp, pos, rot, on_ground)

    def view_entity_movement(
        mut self,
        e: EntityHandle[Self.T.Entities],
        cp: ChunkPos,
        pos: Vec3,
        rot: Rotation,
        on_ground: Bool,
    ):
        """Shows the movement of an entity to the viewers of a chunk."""
        for v in self.viewers_of_chunk(cp):
            self._loader(v).viewer.view_entity_movement(e, pos, rot, on_ground)

    def teleport_entity(mut self, id: UUID, pos: Vec3):
        """Teleports an entity, showing it to the viewers of its chunk (what
        Go's entities do in `Teleport`)."""
        if case .Some(i) = self._ent_index.get(uuid_key(id)):
            var e = self._ents[i].handle.copy()
            for v in self.viewers_of_chunk(self._ents[i].chunk):
                self._loader(v).viewer.view_entity_teleport(e, pos)
            self._ents[i].handle.data.pos = pos

    def set_entity_velocity(mut self, id: UUID, vel: Vec3):
        """Sets an entity's velocity, showing it to the viewers of its chunk."""
        if case .Some(i) = self._ent_index.get(uuid_key(id)):
            self._ents[i].handle.data.vel = vel
            var e = self._ents[i].handle.copy()
            for v in self.viewers_of_chunk(self._ents[i].chunk):
                self._loader(v).viewer.view_entity_velocity(e, vel)

    def _show_entity(mut self, v: LoaderID, e: EntityHandle[Self.T.Entities]):
        # Go `showEntity`.
        ref viewer = self._loader(v).viewer
        viewer.view_entity(e)
        viewer.view_entity_items(e)
        viewer.view_entity_armour(e)

    # ===------------------------------------------------------------------=== #
    # Viewers and loaders
    # ===------------------------------------------------------------------=== #

    def viewers(self, pos: Vec3) -> List[LoaderID]:
        """Returns the loaders viewing the chunk of a position (Go
        `Tx.Viewers`)."""
        return self.viewers_of_chunk(chunk_pos_from_vec3(pos))

    def viewers_of_chunk(self, pos: ChunkPos) -> List[LoaderID]:
        """Returns the loaders viewing a chunk."""
        if case .Some(ci) = self._col_index.get(pos):
            return self._cols[ci].viewers.copy()
        return List[LoaderID]()

    def loaders(self) -> List[LoaderID]:
        """Returns every open loader (Go `allViewers`)."""
        var out = List[LoaderID](capacity=self._viewer_count)
        for i in range(len(self._loaders)):
            if self._loaders[i]:
                out.append((UInt64(self._loader_gens[i]) << 32) | UInt64(i))
        return out^

    def viewer(
        mut self, id: LoaderID
    ) -> ref[self._loaders[0].value().viewer] Self.T.Viewer:
        """Returns the viewer of a loader, for example to drain the packets
        a session's viewer queued. Aborts if the loader is closed."""
        return self._loader(id).viewer

    def _loader(
        mut self, id: LoaderID
    ) -> ref[self._loaders[0].value()] Loader[Self.T.Viewer]:
        var i = Int(id & 0xFFFFFFFF)
        debug_assert(
            UInt32(id >> 32) == self._loader_gens[i], "stale loader ID"
        )
        return self._loaders[i].value()

    def _valid_loader(self, id: LoaderID) -> Bool:
        var i = Int(id & 0xFFFFFFFF)
        return (
            i < len(self._loaders)
            and UInt32(id >> 32) == self._loader_gens[i]
            and Bool(self._loaders[i])
        )

    def add_loader(mut self, radius: Int, var v: Self.T.Viewer) -> LoaderID:
        """Adds a loader at chunk (0, 0) that loads chunks within `radius`
        for a viewer (Go `NewLoader`). The viewer sees the time, time cycle,
        weather and spawn at once; call `move_loader` and `load` to load
        chunks."""
        var loader = Loader[Self.T.Viewer](radius, v^)
        loader.populate_load_queue()
        var i: Int
        if len(self._free_loaders) > 0:
            i = self._free_loaders.pop()
            self._loader_gens[i] += 1
            self._loaders[i] = loader^
        else:
            i = len(self._loaders)
            self._loaders.append(loader^)
            self._loader_gens.append(0)
        var id = (UInt64(self._loader_gens[i]) << 32) | UInt64(i)
        self._viewer_count += 1
        # Go `addWorldViewer`.
        var raining = self._set.raining
        var thundering = self._set.raining and self._set.thundering
        var spawn = self.spawn()
        ref viewer = self._loader(id).viewer
        viewer.view_time(Int(self._set.time))
        viewer.view_time_cycle(self._set.time_cycle)
        viewer.view_weather(raining, thundering)
        viewer.view_world_spawn(spawn)
        return id

    def move_loader(mut self, id: LoaderID, pos: Vec3):
        """Moves a loader (Go `Loader.Move`): chunks now out of range stop
        being viewed and the load queue is rebuilt around the new chunk."""
        var cp = chunk_pos_from_vec3(pos)
        if cp == self._loader(id).pos:
            return
        self._loader(id).pos = cp
        self._evict_unused(id)
        self._loader(id).populate_load_queue()

    def change_loader_radius(mut self, id: LoaderID, radius: Int):
        """Changes a loader's chunk radius (Go `Loader.ChangeRadius`)."""
        self._loader(id).r = radius
        self._evict_unused(id)
        self._loader(id).populate_load_queue()

    def load(mut self, id: LoaderID, n: Int):
        """Loads up to `n` queued chunks, nearest first, and shows each to
        the loader's viewer (Go `Loader.Load`). Chunks are generated here
        if the provider does not have them, so `n` bounds the work."""
        for _ in range(n):
            if len(self._loader(id).load_queue) == 0:
                return
            var pos = self._loader(id).load_queue.pop(0)
            var ci = self._chunk(pos)
            self._view_chunk(id, pos, ci)

    def _view_chunk(mut self, id: LoaderID, pos: ChunkPos, ci: Int):
        # Go `Loader.viewChunk` and `World.addViewer`.
        if pos in self._loader(id).loaded:
            return
        if not self._loader(id).within_load_radius(pos):
            return
        var slot = Int(id & 0xFFFFFFFF)
        var l = self._loaders[slot].take()
        l.viewer.view_chunk(pos, self._dim, self._cols[ci].chunk)
        l.loaded.add(pos)
        self._loaders[slot] = l^
        self._cols[ci].viewers.append(id)
        for key in self._cols[ci].entities.copy():
            if case .Some(i) = self._ent_index.get(key):
                var e = self._ents[i].handle.copy()
                self._show_entity(id, e)

    def loader_has_chunk(mut self, id: LoaderID, pos: ChunkPos) -> Bool:
        """Reports whether a loader's viewer is viewing a chunk (Go
        `Loader.Chunk`)."""
        return pos in self._loader(id).loaded

    def loader_position(mut self, id: LoaderID) -> ChunkPos:
        """Returns the chunk a loader is in."""
        return self._loader(id).pos

    def close_loader(mut self, id: LoaderID) -> Optional[Self.T.Viewer]:
        """Closes a loader (Go `Loader.Close`): its chunks stop being viewed
        and their entities are hidden from its viewer."""
        if not self._valid_loader(id):
            return None
        var loaded = List[ChunkPos]()
        for pos in self._loader(id).loaded:
            loaded.append(pos)
        for pos in loaded:
            self._remove_viewer(pos, id)
        var i = Int(id & 0xFFFFFFFF)
        var l = self._loaders[i].take()
        self._free_loaders.append(i)
        self._viewer_count -= 1
        return l^.into_viewer()

    def _evict_unused(mut self, id: LoaderID):
        # Go `Loader.evictUnused`.
        var loaded = List[ChunkPos]()
        for pos in self._loader(id).loaded:
            loaded.append(pos)
        var gone = List[ChunkPos]()
        for pos in loaded:
            if not self._loader(id).within_load_radius(pos):
                gone.append(pos)
        for pos in gone:
            self._loader(id).loaded.discard(pos)
            self._remove_viewer(pos, id)

    def _remove_viewer(mut self, pos: ChunkPos, id: LoaderID):
        # Go `World.removeViewer`.
        if case .Some(ci) = self._col_index.get(pos):
            _remove_id(self._cols[ci].viewers, id)
            for key in self._cols[ci].entities.copy():
                if case .Some(i) = self._ent_index.get(key):
                    var e = self._ents[i].handle.copy()
                    self._loader(id).viewer.hide_entity(e)

    # ===------------------------------------------------------------------=== #
    # Chunks
    # ===------------------------------------------------------------------=== #

    def chunk_loaded(self, pos: ChunkPos) -> Bool:
        """Reports whether a chunk is loaded."""
        return pos in self._col_index

    def loaded_chunks(self) -> List[ChunkPos]:
        """Returns the positions of every loaded chunk."""
        var out = List[ChunkPos](capacity=len(self._cols))
        for i in range(len(self._cols)):
            out.append(self._cols[i].pos)
        return out^

    def chunk(mut self, pos: ChunkPos) -> ref[self._cols[0].chunk] Chunk:
        """Returns a chunk, loading or generating it if needed (Go
        `Tx.chunk`)."""
        var ci = self._chunk(pos)
        return self._cols[ci].chunk

    def _chunk(mut self, pos: ChunkPos) -> Int:
        # Go `Tx.chunk` and `loadChunk`: the index of the loaded column.
        if case .Some(ci) = self._col_index.get(pos):
            return ci
        var loaded: Optional[ChunkColumn] = None
        var broken = False
        try:
            loaded = self._provider.load_column(pos, self._dim)
        except e:
            self.last_error = String(t"load chunk {pos}: {e}")
            broken = True
        var col: ChunkColumn
        if case .Some(ref c) = loaded:
            col = c.copy()
        else:
            var ch = Chunk(self._br[].air_runtime_id(), self._ra)
            if not broken:
                self._generator.generate_chunk(pos, ch)
            col = ChunkColumn(ch^)
        var ci = self._add_chunk(pos, col^)
        self._cols[ci].broken = broken
        return ci

    def _add_chunk(mut self, pos: ChunkPos, var c: ChunkColumn) -> Int:
        # Go `loadChunk`'s Fill, then `addChunk` and `columnFrom`. Derived
        # block states are not computed yet.
        var ci = len(self._cols)
        self._cols.append(Column(pos, c.chunk.copy()))
        self._col_index[pos] = ci
        var one = List[ChunkPointer]()
        one.append(chunk_pointer(self._cols[ci].chunk))
        var area = LightArea(self._br[], one^, Int(pos.x()), Int(pos.z()))
        area.fill()
        for ref se in c.entities:
            try:
                var maybe = EntityHandle[Self.T.Entities].decode_nbt(
                    se.id, se.data
                )
                if case .Some(ref h) = maybe:
                    var key = uuid_key(h.id)
                    if key in self._ent_index:
                        continue
                    self._cols[ci].entities.append(key)
                    self._ent_index[key] = len(self._ents)
                    self._ents.append(_EntityEntry(h.copy(), pos))
                else:
                    self.last_error = String(
                        t"read column {pos}: entity without known identifier"
                    )
            except e:
                self.last_error = String(t"read column {pos}: {e}")
        var scheduled = List[ScheduledTick]()
        for t in c.scheduled_blocks:
            var tick = self._scheduled.current_tick + (t.tick - c.tick)
            scheduled.append(
                ScheduledTick(t.pos, t.block, self._block_hash(t.block), tick)
            )
        self._scheduled.add(scheduled)
        self._calculate_light(pos)
        return ci

    def _calculate_light(mut self, centre: ChunkPos):
        # Go `calculateLight`: spreads the light of every loaded chunk
        # around centre whose neighbours are now all loaded.
        for x in range(-1, 2):
            for z in range(-1, 2):
                var pos = ChunkPos(centre.x() + Int32(x), centre.z() + Int32(z))
                if pos in self._col_index:
                    self._spread_light(pos)

    def _spread_light(mut self, pos: ChunkPos):
        # Go `spreadLight`.
        var ptrs = List[ChunkPointer](capacity=9)
        for z in range(-1, 2):
            for x in range(-1, 2):
                var p = ChunkPos(pos.x() + Int32(x), pos.z() + Int32(z))
                var found = self._col_index.get(p)
                if not found:
                    # Not all surrounding chunks exist: stop spreading.
                    return
                ptrs.append(chunk_pointer(self._cols[found.value()].chunk))
        var area = LightArea(
            self._br[], ptrs^, Int(pos.x()) - 1, Int(pos.z()) - 1
        )
        area.spread()

    def _column_to(mut self, ci: Int) raises -> ChunkColumn:
        # Go `columnTo`.
        var pos = self._cols[ci].pos
        var c = ChunkColumn(self._cols[ci].chunk.copy())
        # Providers do not store light; it is computed again on load.
        c.chunk.clear_light()
        for key in self._cols[ci].entities:
            if case .Some(i) = self._ent_index.get(key):
                ref h = self._ents[i].handle
                c.entities.append(ChunkEntity(h.saved_id(), h.encode_nbt()))
        for t in self._scheduled.from_chunk(pos):
            c.scheduled_blocks.append(ScheduledBlockUpdate(t.pos, t.rid, t.t))
        c.tick = self._scheduled.current_tick
        return c^

    def _save_chunk(mut self, ci: Int):
        # Go `saveChunk`.
        # Dragonfly saves only chunks marked modified, but entities move
        # without marking their chunk, so a moved entity was saved at its
        # old position or lost. Chunks holding entities are always saved.
        if self._read_only:
            return
        if not self._cols[ci].modified and len(self._cols[ci].entities) == 0:
            return
        if self._cols[ci].broken:
            return
        self._cols[ci].chunk.compact()
        var pos = self._cols[ci].pos
        try:
            var col = self._column_to(ci)
            self._provider.store_column(pos, self._dim, col^)
            self._cols[ci].modified = False
        except e:
            self.last_error = String(t"save chunk {pos}: {e}")

    def _close_chunk(mut self, pos: ChunkPos):
        # Go `closeChunk`: save, drop scheduled updates, close entities
        # (Go's entities remove themselves in Close), unload.
        var found = self._col_index.get(pos)
        if not found:
            return
        self._save_chunk(found.value())
        self._scheduled.remove_chunk(pos)
        var keys = self._cols[found.value()].entities.copy()
        for key in keys:
            if case .Some(i) = self._ent_index.get(key):
                var id = self._ents[i].handle.id
                _ = self.remove_entity(id)
        var ci = self._col_index.pop(pos, -1)
        if ci < 0:
            return
        var last = len(self._cols) - 1
        if ci != last:
            self._cols.swap_elements(ci, last)
            self._col_index[self._cols[ci].pos] = ci
        _ = self._cols.pop()

    def close_unused_chunks(mut self):
        """Saves and unloads every chunk no loader views (Go
        `closeUnusedChunks`)."""
        var unused = List[ChunkPos]()
        for i in range(len(self._cols)):
            if len(self._cols[i].viewers) == 0:
                unused.append(self._cols[i].pos)
        for pos in unused:
            self._close_chunk(pos)

    def save(mut self):
        """Saves every modified chunk and the settings to the provider (Go
        `Save`)."""
        if self._read_only:
            return
        for ci in range(len(self._cols)):
            self._save_chunk(ci)
        try:
            self._provider.save_settings(self._set)
        except e:
            self.last_error = String(t"save settings: {e}")

    def close(mut self):
        """Closes the world (Go `Close`): the handler's `handle_close` runs,
        then every chunk is saved and unloaded and the provider closed.
        Calling it again does nothing."""
        if self._closed:
            return
        self._closed = True
        if self._handler:
            var h = self._handler.take()
            h.handle_close(self)
        self._handler = None
        var all = self.loaded_chunks()
        for pos in all:
            self._close_chunk(pos)
        if not self._read_only:
            try:
                self._provider.save_settings(self._set)
            except e:
                self.last_error = String(t"save settings: {e}")
        try:
            self._provider.close()
        except e:
            self.last_error = String(t"close provider: {e}")

    def closed(self) -> Bool:
        """Reports whether `close` was called."""
        return self._closed

    def provider(ref self) -> ref[self._provider] Self.T.Provider:
        """Returns the world's provider."""
        return self._provider

    # ===------------------------------------------------------------------=== #
    # Ticking (Go tick.go)
    # ===------------------------------------------------------------------=== #

    def tick(mut self, now_ms: Int) -> Int:
        """Runs every world tick that is due, and the periodic chunk unload
        and save. The server loop calls it whenever `next_deadline_ms` has
        passed.

        A loop that fell behind catches up at most 10 ticks and then skips
        the rest, as Go's `time.Ticker` drops ticks.
        """
        var n = 0
        while now_ms >= self._next_tick_ms and n < _MAX_CATCH_UP:
            self.advance_tick()
            self._next_tick_ms += TICK_MS
            n += 1
        if now_ms >= self._next_tick_ms:
            self._next_tick_ms = now_ms + TICK_MS
        if now_ms >= self._next_unload_ms:
            self.close_unused_chunks()
            self._next_unload_ms = now_ms + self._chunk_unload_interval_ms
        if self._save_interval_ms > 0 and now_ms >= self._next_save_ms:
            self.save()
            self._next_save_ms = now_ms + self._save_interval_ms
        return n

    def next_deadline_ms(self) -> Int:
        """Returns when `tick` next has work to do."""
        var d = min(self._next_tick_ms, self._next_unload_ms)
        if self._save_interval_ms > 0:
            d = min(d, self._next_save_ms)
        return d

    def advance_tick(mut self):
        """Runs one world tick (Go `ticker.tick`, `AdvanceTick`): time,
        weather, entities, scheduled updates, random ticks and neighbour
        updates. Worlds without viewers do not tick unless synchronous."""
        if self._set.spawn.y() > self._ra.max() and self._dim == OVERWORLD:
            # Vanilla sets the spawn's Y above the world to mean "on the
            # highest block".
            var s = self._set.spawn
            self._set.spawn = Pos(
                s.x(), self.highest_obstructing_block(s.x(), s.z()) + 1, s.z()
            )
        if (
            self._viewer_count == 0
            and self._set.current_tick != 0
            and not self._synchronous
        ):
            return
        self._set.current_tick += 1
        if self._set.time_cycle:
            self._set.time += 1
        if self._set.weather_cycle:
            advance_weather(self._set, self._r)

        var rain = self._set.raining
        var thunder = self._set.thundering and self._set.raining
        var tick = self._set.current_tick
        var tim = Int(self._set.time)
        var cycle = self._set.time_cycle
        if self._set.required_sleep_ticks > 0:
            # TODO: advance the day once sleeping players are ported.
            self._set.required_sleep_ticks -= 1

        if tick % 20 == 0:
            for id in self.loaders():
                if self._dim.time_cycle() and cycle:
                    self._loader(id).viewer.view_time(tim)
                if self._dim.weather_cycle():
                    self._loader(id).viewer.view_weather(rain, thunder)
        # TODO: lightning while thundering (needs the lightning entity).

        self._tick_entities(tick)
        self._tick_scheduled(tick)
        self._tick_blocks_randomly(tick)
        self._perform_neighbour_updates()

    def _tick_entities(mut self, tick: Int64):
        # Go `ticker.tickEntities`.
        var keys = List[UInt128](capacity=len(self._ents))
        for ref e in self._ents:
            keys.append(uuid_key(e.handle.id))
        for key in keys:
            var found = self._ent_index.get(key)
            if not found:
                continue
            var i = found.value()
            var cp = chunk_pos_from_vec3(self._ents[i].handle.data.pos)
            var cfound = self._col_index.get(cp)
            if not cfound:
                continue
            var ci = cfound.value()
            var last = self._ents[i].chunk
            if last != cp:
                # The entity moved to another chunk: hide it from viewers
                # that no longer see it and show it to new ones.
                self._ents[i].chunk = cp
                self._cols[ci].entities.append(key)
                self._cols[ci].modified = True
                var old_viewers = List[LoaderID]()
                if case .Some(oci) = self._col_index.get(last):
                    _remove_key(self._cols[oci].entities, key)
                    self._cols[oci].modified = True
                    old_viewers = self._cols[oci].viewers.copy()
                var new_viewers = self._cols[ci].viewers.copy()
                var e = self._ents[i].handle.copy()
                for v in old_viewers:
                    if v not in new_viewers:
                        self._loader(v).viewer.hide_entity(e)
                for v in new_viewers:
                    if v not in old_viewers:
                        self._show_entity(v, e)
            if self._synchronous or len(self._cols[ci].viewers) > 0:
                if Self.T.Entities.ticks(self._ents[i].handle.state):
                    self._tick_entity(key, tick)

    def _tick_entity(mut self, key: UInt128, tick: Int64):
        # The entity leaves the world while it ticks, so that it can use
        # the world mutably. It goes back to its slot afterwards, so that
        # entities tick in a stable order (Go ranges over a map, in random
        # order).
        var slot = self._ent_index.get(key).value()
        var entry = self._take_entity(key)
        var cp = entry.chunk
        var h = entry^.into_handle()
        self._ticking = key
        self._ticking_removed = False
        var m = Self.T.Entities.tick[Self.T](h, self, tick)
        self._ticking = None
        if self._ticking_removed:
            self._ticking_removed = False
            if self._handler:
                var hd = self._handler.take()
                hd.handle_entity_despawn(self, h)
                self._handler = hd^
            self._unlink_entity(key, cp, h)
            return
        self._ent_index[key] = len(self._ents)
        var shown = h.copy()
        self._ents.append(_EntityEntry(h^, cp))
        var last = len(self._ents) - 1
        if slot < last:
            self._ents.swap_elements(slot, last)
            self._ent_index[uuid_key(self._ents[slot].handle.id)] = slot
            self._ent_index[uuid_key(self._ents[last].handle.id)] = last
        if case .Some(mv) = m:
            # Go `Movement.Send`.
            for v in self.viewers_of_chunk(cp):
                if mv.moved:
                    self._loader(v).viewer.view_entity_movement(
                        shown, mv.pos, mv.rot, mv.on_ground
                    )
                if mv.vel_changed:
                    self._loader(v).viewer.view_entity_velocity(shown, mv.vel)

    def _tick_scheduled(mut self, tick: Int64):
        # Go `scheduledTickQueue.tick`.
        var due = self._scheduled.take_due(tick)
        for t in due:
            var rid = self.block(t.pos)
            var done = False
            if self._block_hash(rid) == t.bhash:
                done = Self.T.Blocks.scheduled_tick(
                    self._br[].kind(rid),
                    self._br[].state_hash(rid),
                    t.pos,
                    self,
                )
            if not done:
                var li = self._additional_liquid(t.pos)
                if li and self._block_hash(li.value()) == t.bhash:
                    _ = Self.T.Blocks.scheduled_tick(
                        self._br[].kind(li.value()),
                        self._br[].state_hash(li.value()),
                        t.pos,
                        self,
                    )

    def _additional_liquid(mut self, pos: Pos) -> Optional[UInt32]:
        # Go `Tx.additionalLiquid`: the liquid on layer 1, if any.
        if pos.out_of_bounds(self._ra):
            return None
        var ci = self._chunk(chunk_pos_from_block_pos(pos))
        var rid = self._cols[ci].chunk.block(
            UInt8(pos.x() & 0xF), Int16(pos.y()), UInt8(pos.z() & 0xF), 1
        )
        if self._br[].liquid_block(rid):
            return rid
        return None

    def _perform_neighbour_updates(mut self):
        # Go `ticker.performNeighbourUpdates`.
        var updates = self._neighbour_updates^
        self._neighbour_updates = List[NeighbourUpdate]()
        for u in updates:
            var rid = self.block(u.pos)
            _ = Self.T.Blocks.neighbour_update_tick(
                self._br[].kind(rid),
                self._br[].state_hash(rid),
                u.pos,
                u.neighbour,
                self,
            )
            var li = self._additional_liquid(u.pos)
            if li:
                _ = Self.T.Blocks.neighbour_update_tick(
                    self._br[].kind(li.value()),
                    self._br[].state_hash(li.value()),
                    u.pos,
                    u.neighbour,
                    self,
                )

    def _tick_blocks_randomly(mut self, tick: Int64):
        # Go `ticker.tickBlocksRandomly`. Block entity ticks (`TickerBlock`)
        # come with block entities.
        var r = self._set.tick_range
        if r == 0 or self._random_tick_speed <= 0:
            return
        var loaded = List[ChunkPos]()
        if self._synchronous:
            loaded = self.loaded_chunks()
        else:
            for id in self.loaders():
                loaded.append(self._loader(id).pos)
        var g = RandUint4()
        var random_blocks = List[Pos]()
        var min_sub = self._ra.min() >> 4
        for ci in range(len(self._cols)):
            var pos = self._cols[ci].pos
            if not any_within_distance(pos, loaded, r):
                continue
            var cx = Int(pos.x()) << 4
            var cz = Int(pos.z()) << 4
            var n_sub = len(self._cols[ci].chunk.sub())
            for _ in range(self._random_tick_speed):
                var x = g.uint4(self._r)
                var y = g.uint4(self._r)
                var z = g.uint4(self._r)
                for i in range(n_sub):
                    if self._cols[ci].chunk.sub()[i].empty():
                        continue
                    var rid = self._cols[ci].chunk.sub()[i].block(x, y, z, 0)
                    if self._br[].random_tick_block(rid):
                        var sub_y = (i + min_sub) << 4
                        random_blocks.append(
                            Pos(cx + Int(x), sub_y + Int(y), cz + Int(z))
                        )
                        x = g.uint4(self._r)
                        y = g.uint4(self._r)
                        z = g.uint4(self._r)
        for pos in random_blocks:
            var rid = self.block(pos)
            _ = Self.T.Blocks.random_tick(
                self._br[].kind(rid), self._br[].state_hash(rid), pos, self
            )


struct WorldSource[o: MutOrigin, T: WorldTypes](
    BlockSource, ImplicitlyCopyable
):
    """A world seen as a `BlockSource` (Go `*Tx` as a `BlockSource`); see
    `World.source`."""

    var _w: Pointer[World[Self.T], Self.o]

    def __init__(out self, w: Pointer[World[Self.T], Self.o]):
        """Creates the view."""
        self._w = w

    def block(self, pos: Pos) -> UInt32:
        """Returns the block at a position, loading or generating its chunk
        if needed (Go `Tx.Block`)."""
        return self._w[].block(pos)

    def kind(self, rid: UInt32) -> UInt64:
        """Returns the base hash of a block's type (the registry's `kind`)."""
        return self._w[]._br[].kind(rid)

    def state_hash(self, rid: UInt32) -> UInt64:
        """Returns a block's state hash (the registry's `state_hash`)."""
        return self._w[]._br[].state_hash(rid)


def _remove_key(mut l: List[UInt128], key: UInt128):
    for i in range(len(l)):
        if l[i] == key:
            _ = l.pop(i)
            return


def _remove_id(mut l: List[LoaderID], id: LoaderID):
    for i in range(len(l)):
        if l[i] == id:
            _ = l.pop(i)
            return
