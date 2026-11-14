"""A world built for tests: a recording viewer, a recording handler, probe
blocks with scheduled and neighbour ticks, and a walking entity."""

from minecraft.nbt.tree import Tag, Tree
from minecraft.protocol.uuid import UUID
from std.memory import ArcPointer

from ignis.block.air import Air
from ignis.block.bedrock import Bedrock
from ignis.block.carpet import Carpet
from ignis.block.cube.bbox import BBox
from ignis.block.cube.pos import Pos
from ignis.block.cube.rotation import Rotation
from ignis.block.dirt import Dirt
from ignis.block.grass import Grass
from ignis.block.stone import Stone
from ignis.entity.text import Text
from ignis.block.register import VanillaBlocks, vanilla_block_registry
from ignis.entity.register import VanillaEntities
from ignis.mgl64 import Vec3
from ignis.world.biome.plains import Plains
from ignis.world.block import (
    Block,
    NeighbourUpdateTicker,
    RandomTicker,
    ScheduledTicker,
)
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.block_set import BlockSet
from ignis.world.block_state import BlockState
from ignis.world.chunk.chunk import Chunk
from ignis.world.conf import Config
from ignis.world.dimension import Dimension
from ignis.world.entity import (
    EntityData,
    EntityHandle,
    EntityMovement,
    EntitySet,
    EntityTypes,
    TickerEntity,
)
from ignis.world.generator.flat import Flat
from ignis.world.handler import Handler
from ignis.world.position import ChunkPos
from ignis.world.provider import MemoryProvider
from ignis.world.tx import SetOpts
from ignis.world.viewer import Viewer
from ignis.world.world import World, WorldTypes


@fieldwise_init
struct ScheduledProbe(Block, Equatable, ImplicitlyCopyable, ScheduledTicker):
    """Sand that puts dirt on top of itself when its scheduled tick runs."""

    comptime BASE_HASH: UInt64 = 1 << 40

    def encode_block(self) -> BlockState:
        return BlockState("minecraft:sand")

    def hash(self) -> UInt64:
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        return Self()

    @staticmethod
    def all_states() -> List[Self]:
        return [Self()]

    def scheduled_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        tx.set_block(pos.add(Pos(0, 1, 0)), Dirt())


@fieldwise_init
struct NeighbourProbe(
    Block, Equatable, ImplicitlyCopyable, NeighbourUpdateTicker
):
    """Red sand that turns into stone when a neighbour changes."""

    comptime BASE_HASH: UInt64 = (1 << 40) + 1

    def encode_block(self) -> BlockState:
        return BlockState("minecraft:red_sand")

    def hash(self) -> UInt64:
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        return Self()

    @staticmethod
    def all_states() -> List[Self]:
        return [Self()]

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        if changed_neighbour != pos:
            tx.set_block(pos, Stone())


@fieldwise_init
struct RandomProbe(Block, Equatable, ImplicitlyCopyable, RandomTicker):
    """Gravel that turns into stone when ticked randomly."""

    comptime BASE_HASH: UInt64 = (1 << 40) + 2

    def encode_block(self) -> BlockState:
        return BlockState("minecraft:gravel")

    def hash(self) -> UInt64:
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        return Self()

    @staticmethod
    def all_states() -> List[Self]:
        return [Self()]

    def random_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        var opts = SetOpts()
        opts.disable_block_updates = True
        tx.set_block(pos, Stone(), opts)


comptime TestBlocks = BlockSet[
    Air,
    Bedrock,
    Carpet,
    Dirt,
    Grass,
    Stone,
    ScheduledProbe,
    NeighbourProbe,
    RandomProbe,
]


@fieldwise_init
struct Walker(Copyable, TickerEntity):
    """An entity that walks one block along +x every tick for `steps`
    ticks, then removes itself."""

    comptime IDENTIFIER: StaticString = "ignis:walker"

    var steps: Int

    def bbox(self, data: EntityData) -> BBox:
        return BBox.box(-0.5, 0, -0.5, 0.5, 1, 0.5)

    def encode_nbt(self, data: EntityData, mut tree: Tree, tag: Tag) raises:
        _ = tree.put_int(tag, "Steps", Int32(self.steps))

    @staticmethod
    def decode_nbt(tree: Tree, tag: Tag, mut data: EntityData) raises -> Self:
        return Self(Int(tree.get_int(tag, "Steps")))

    def tick[
        T: WorldTypes
    ](
        mut self,
        id: UUID,
        mut data: EntityData,
        mut tx: World[T],
        current: Int64,
    ) -> Optional[EntityMovement]:
        if self.steps == 0:
            _ = tx.remove_entity(id)
            return None
        self.steps -= 1
        data.pos = data.pos.add(Vec3(1, 0, 0))
        return EntityMovement(
            data.pos, data.rot, data.vel, True, moved=True, vel_changed=False
        )


comptime TestEntities = EntitySet[Text, Walker]


struct RecordingViewer(Defaultable, Viewer):
    """Records every call as a line."""

    var events: List[String]

    def __init__(out self):
        self.events = List[String]()

    def count(self, prefix: String) -> Int:
        var n = 0
        for e in self.events:
            if e.startswith(prefix):
                n += 1
        return n

    def view_entity[E: EntityTypes](mut self, e: EntityHandle[E]):
        self.events.append(String(t"entity {e.identifier()} {e.data.name}"))

    def hide_entity[E: EntityTypes](mut self, e: EntityHandle[E]):
        self.events.append(String(t"hide {e.identifier()} {e.data.name}"))

    def view_entity_movement[
        E: EntityTypes
    ](mut self, e: EntityHandle[E], pos: Vec3, rot: Rotation, on_ground: Bool,):
        self.events.append(String(t"move {e.identifier()} {pos}"))

    def view_entity_teleport[
        E: EntityTypes
    ](mut self, e: EntityHandle[E], pos: Vec3):
        self.events.append(String(t"teleport {e.identifier()} {pos}"))

    def view_chunk(mut self, pos: ChunkPos, dim: Dimension, c: Chunk):
        self.events.append(String(t"chunk {pos}"))

    def view_time(mut self, t: Int):
        self.events.append(String(t"time {t}"))

    def view_time_cycle(mut self, do_day_light_cycle: Bool):
        self.events.append(String(t"time_cycle {do_day_light_cycle}"))

    def view_block_update(mut self, pos: Pos, rid: UInt32, layer: Int):
        self.events.append(String(t"block {pos} {rid} {layer}"))

    def view_world_spawn(mut self, pos: Pos):
        self.events.append(String(t"spawn {pos}"))

    def view_weather(mut self, raining: Bool, thunder: Bool):
        self.events.append(String(t"weather {raining} {thunder}"))


struct RecordingHandler(Defaultable, Handler):
    """Counts spawn, despawn and close events."""

    var spawned: Int
    var despawned: Int
    var closed: Int

    def __init__(out self):
        self.spawned = 0
        self.despawned = 0
        self.closed = 0

    def handle_entity_spawn[
        T: WorldTypes
    ](mut self, mut tx: World[T], e: EntityHandle[T.Entities]):
        self.spawned += 1

    def handle_entity_despawn[
        T: WorldTypes
    ](mut self, mut tx: World[T], e: EntityHandle[T.Entities]):
        self.despawned += 1

    def handle_close[T: WorldTypes](mut self, mut tx: World[T]):
        self.closed += 1


struct TestWorld(WorldTypes):
    comptime Generator = Flat
    comptime Provider = MemoryProvider
    comptime Viewer = RecordingViewer
    comptime Handler = RecordingHandler
    comptime Blocks = TestBlocks
    comptime Entities = TestEntities


def test_registry() raises -> ArcPointer[BasicBlockRegistry]:
    var br = BasicBlockRegistry.load("resources/block_states.nbt")
    TestBlocks.register_all(br)
    br.finalize()
    return ArcPointer(br^)


def flat(br: BasicBlockRegistry) -> Flat:
    """Grass on dirt on bedrock: the top block is at y = -62."""
    return Flat(
        Plains(),
        [
            br.block_runtime_id(Grass()),
            br.block_runtime_id(Dirt()),
            br.block_runtime_id(Bedrock()),
        ],
    )


def new_world(synchronous: Bool = False) raises -> World[TestWorld]:
    var br = test_registry()
    var conf = Config[TestWorld](flat(br[]), MemoryProvider(), br)
    conf.seed = (UInt64(1), UInt64(2))
    conf.synchronous = synchronous
    return conf^.new(0)


struct ItemWorld(WorldTypes):
    """`TestWorld` with the vanilla entity set, for item entities."""

    comptime Generator = Flat
    comptime Provider = MemoryProvider
    comptime Viewer = RecordingViewer
    comptime Handler = RecordingHandler
    comptime Blocks = TestBlocks
    comptime Entities = VanillaEntities


def new_item_world() raises -> World[ItemWorld]:
    var br = test_registry()
    var conf = Config[ItemWorld](flat(br[]), MemoryProvider(), br)
    conf.seed = (UInt64(1), UInt64(2))
    conf.synchronous = True
    return conf^.new(0)


struct VanillaWorld(WorldTypes):
    """A flat world with every vanilla block and entity type."""

    comptime Generator = Flat
    comptime Provider = MemoryProvider
    comptime Viewer = RecordingViewer
    comptime Handler = RecordingHandler
    comptime Blocks = VanillaBlocks
    comptime Entities = VanillaEntities


def new_vanilla_world() raises -> World[VanillaWorld]:
    var br = ArcPointer(vanilla_block_registry("resources/block_states.nbt"))
    var conf = Config[VanillaWorld](flat(br[]), MemoryProvider(), br)
    conf.seed = (UInt64(1), UInt64(2))
    conf.synchronous = True
    return conf^.new(0)
