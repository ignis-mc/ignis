"""Compares worlds ticked by Ignis with the regions Dragonfly recorded in
`test/data/behaviour/*.txt` (written by `interop/behaviour`)."""

from std.collections import Dict
from std.testing import assert_equal

from ignis.block.bedrock import Bedrock
from ignis.block.cube.pos import Pos
from ignis.block.dirt import Dirt
from ignis.block.grass import Grass
from ignis.block.register import VanillaBlocks, vanilla_block_registry
from ignis.entity.register import VanillaEntities
from ignis.world.block import Block
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.chunk.chunk import Chunk
from ignis.world.conf import Config
from ignis.world.dimension import Dimension
from ignis.world.generator import Generator
from ignis.world.generator.flat import Flat
from ignis.world.position import ChunkPos
from ignis.world.provider import MemoryProvider
from ignis.world.world import World, WorldTypes
from std.memory import ArcPointer

from .world_runtime import RecordingHandler, RecordingViewer, flat


struct BehaviourVectors(Movable):
    """The lines of one vector file, grouped by scenario and tick."""

    var _lines: Dict[String, List[String]]
    var _ticks: Dict[String, List[Int]]

    def __init__(out self, path: String) raises:
        self._lines = Dict[String, List[String]]()
        self._ticks = Dict[String, List[Int]]()
        var text: String
        with open(path, "r") as f:
            text = f.read()
        for raw in text.split("\n"):
            var line = String(raw)
            if line.byte_length() == 0:
                continue
            var parts = line.split("\t")
            var name = String(parts[0])
            var tick = Int(String(parts[1]))
            var key = String(t"{name}@{tick}")
            if key not in self._lines:
                self._lines[key] = List[String]()
                if name not in self._ticks:
                    self._ticks[name] = List[Int]()
                self._ticks[name].append(tick)
            var rest = String("\t").join(parts[2:])
            self._lines[key].append(rest)

    def ticks(self, name: String) raises -> List[Int]:
        """Returns the checkpoint ticks of a scenario."""
        return self._ticks[name].copy()

    def lines(self, name: String, tick: Int) raises -> List[String]:
        """Returns the recorded lines of a scenario at a tick."""
        return self._lines[String(t"{name}@{tick}")].copy()


def dump_region[
    T: WorldTypes
](mut w: World[T], lo: Pos, hi: Pos, items: Int) -> List[String]:
    """Renders a region as `interop/behaviour` does: `x,y,z layer rid` for
    every block that differs from the flat world (grass at y=-62, dirt,
    bedrock, air above; layer 1 only for a liquid behind a non-liquid),
    then the falling blocks, the dropped items (the world queues drops;
    Dragonfly's item entities merge, so items are counted) and other
    entities."""
    var out = List[String]()
    var br = w.block_registry()
    var air = br[].air_runtime_id()
    var grass = br[].block_runtime_id(Grass())
    var dirt = br[].block_runtime_id(Dirt())
    var bedrock = br[].block_runtime_id(Bedrock())
    for y in range(lo.y(), hi.y() + 1):
        var base = air
        if y == -62:
            base = grass
        elif y == -63:
            base = dirt
        elif y == -64:
            base = bedrock
        for z in range(lo.z(), hi.z() + 1):
            for x in range(lo.x(), hi.x() + 1):
                var pos = Pos(x, y, z)
                var rid = w.block(pos)
                if rid != base:
                    out.append(String(t"{x},{y},{z}\t0\t{rid}"))
                if br[].liquid_block(rid):
                    continue
                if case .Some(l) = w.liquid(pos):
                    out.append(String(t"{x},{y},{z}\t1\t{l}"))
    var falling = 0
    var other = 0
    for id in w.entities():
        if w.entity(id).value().identifier() == "minecraft:falling_block":
            falling += 1
        else:
            other += 1
    out.append(String(t"entities\t{falling}\t{items}\t{other}"))
    return out^


def expected_lines(
    v: BehaviourVectors, name: String, tick: Int
) raises -> List[String]:
    """Returns the recorded lines without the state names."""
    var out = List[String]()
    for l in v.lines(name, tick):
        var parts = l.split("\t")
        if String(parts[0]) != "entities" and len(parts) >= 4:
            out.append(String(t"{parts[0]}\t{parts[1]}\t{parts[2]}"))
        else:
            out.append(l)
    return out^


def assert_region_equal(
    got: List[String], want: List[String], label: String
) raises:
    """Fails with the first differing line of two dumps."""
    var n = min(len(got), len(want))
    for i in range(n):
        if got[i] != want[i]:
            assert_equal(got[i], want[i], String(t"{label}: line {i}"))
    assert_equal(len(got), len(want), String(t"{label}: line count"))


@fieldwise_init
struct Placement(Copyable, ImplicitlyCopyable):
    """A block `FeatureFlat` sets while generating."""

    var pos: Pos
    var rid: UInt32


struct FeatureFlat(Copyable, Generator):
    """The flat test world with blocks placed while generating, so that the
    light calculated on load sees them (`featureFlat` in
    `interop/behaviour/features.go`)."""

    var flat: Flat
    var placements: List[Placement]

    def __init__(out self, var flat: Flat, var placements: List[Placement]):
        self.flat = flat^
        self.placements = placements^

    def generate_chunk(self, pos: ChunkPos, mut chunk: Chunk):
        self.flat.generate_chunk(pos, chunk)
        for p in self.placements:
            if p.pos.x() >> 4 != Int(pos.x()) or p.pos.z() >> 4 != Int(pos.z()):
                continue
            chunk.set_block(
                UInt8(p.pos.x() & 15),
                Int16(p.pos.y()),
                UInt8(p.pos.z() & 15),
                0,
                p.rid,
            )

    def default_spawn(self, dim: Dimension) -> Pos:
        return self.flat.default_spawn(dim)


def box[
    B: Block
](br: BasicBlockRegistry, lo: Pos, hi: Pos, b: B) -> List[Placement]:
    """Returns placements of `b` filling the box `[lo, hi]` (Go `box`)."""
    var out = List[Placement]()
    var rid = br.block_runtime_id(b)
    for y in range(lo.y(), hi.y() + 1):
        for z in range(lo.z(), hi.z() + 1):
            for x in range(lo.x(), hi.x() + 1):
                out.append(Placement(Pos(x, y, z), rid))
    return out^


struct FeatureWorld(WorldTypes):
    """A vanilla world generated by `FeatureFlat`."""

    comptime Generator = FeatureFlat
    comptime Provider = MemoryProvider
    comptime Viewer = RecordingViewer
    comptime Handler = RecordingHandler
    comptime Blocks = VanillaBlocks
    comptime Entities = VanillaEntities


def new_feature_world(
    var placements: List[Placement], random_tick_speed: Int = -1
) raises -> World[FeatureWorld]:
    """Returns a synchronous feature world seeded like the Go worlds."""
    var br = ArcPointer(vanilla_block_registry("resources/block_states.nbt"))
    var gen = FeatureFlat(flat(br[]), placements^)
    var conf = Config[FeatureWorld](gen^, MemoryProvider(), br)
    conf.seed = (UInt64(1), UInt64(2))
    conf.synchronous = True
    conf.random_tick_speed = random_tick_speed
    return conf^.new(0)


def vanilla_registry() raises -> BasicBlockRegistry:
    """Returns the vanilla block registry."""
    return vanilla_block_registry("resources/block_states.nbt")


struct ScenarioRun(Movable):
    """Ticks a world through the checkpoints of a recorded scenario."""

    var vectors: BehaviourVectors
    var name: String
    var lo: Pos
    var hi: Pos
    var tick: Int
    var items: Int

    def __init__(out self, path: String, name: String, lo: Pos, hi: Pos) raises:
        self.vectors = BehaviourVectors(path)
        self.name = name
        self.lo = lo
        self.hi = hi
        self.tick = 0
        self.items = 0

    def check_until[
        T: WorldTypes
    ](mut self, mut w: World[T], last: Int = Int.MAX) raises:
        """Ticks to every checkpoint up to `last` and compares the region."""
        for cp in self.vectors.ticks(self.name):
            if cp <= self.tick or cp > last:
                continue
            while self.tick < cp:
                w.advance_tick()
                for d in w.take_item_drops():
                    self.items += d.stack.count()
                self.tick += 1
            var got = dump_region(w, self.lo, self.hi, self.items)
            assert_region_equal(
                got,
                expected_lines(self.vectors, self.name, cp),
                String(t"{self.name}@{cp}"),
            )
