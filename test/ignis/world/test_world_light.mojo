"""The world's light against Dragonfly: chunks loaded through the world in
each scenario's order, then the scenario's block changes made with
`set_block_runtime_id`, which relights incrementally."""

from ignis.block.cube.pos import Pos
from ignis.block.register import VanillaBlocks, vanilla_block_registry
from ignis.block.stone import Stone
from ignis.block.torch import Torch
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.chunk.chunk import Chunk
from ignis.world.conf import Config
from ignis.world.dimension import Dimension
from ignis.world.generator import Generator
from ignis.world.position import ChunkPos
from ignis.world.provider import MemoryProvider
from ignis.world.world import World, WorldTypes
from std.memory import ArcPointer
from std.testing import TestSuite, assert_equal, assert_true
from support.light_vectors import (
    Scenario,
    build_chunks,
    light_hashes,
    load_scenarios,
)
from support.world_runtime import (
    RecordingHandler,
    RecordingViewer,
    TestEntities,
)


struct ScenarioGenerator(Generator):
    """Hands out the chunks of a scenario."""

    var order: List[ChunkPos]
    var chunks: List[Chunk]

    def __init__(out self, var order: List[ChunkPos], var chunks: List[Chunk]):
        self.order = order^
        self.chunks = chunks^

    def generate_chunk(self, pos: ChunkPos, mut chunk: Chunk):
        for i in range(len(self.order)):
            if self.order[i] == pos:
                chunk = self.chunks[i].copy()

    def default_spawn(self, dim: Dimension) -> Pos:
        return Pos(0, 0, 0)


struct LightWorld(WorldTypes):
    comptime Generator = ScenarioGenerator
    comptime Provider = MemoryProvider
    comptime Viewer = RecordingViewer
    comptime Handler = RecordingHandler
    comptime Blocks = VanillaBlocks
    comptime Entities = TestEntities


def _world(
    br: ArcPointer[BasicBlockRegistry], s: Scenario
) raises -> World[LightWorld]:
    var gen = ScenarioGenerator(
        s.order.copy(), build_chunks(s, br[].air_runtime_id())
    )
    var conf = Config[LightWorld](gen^, MemoryProvider(), br)
    conf.synchronous = True
    return conf^.new(0)


def _check(mut w: World[LightWorld], s: Scenario, step: Int) raises:
    ref st = s.steps[step]
    for e in st.expected:
        var h = light_hashes(w.chunk(e.pos))
        if h[0] != e.sky or h[1] != e.block:
            raise Error(
                t"{s.name} step {step}: chunk {e.pos} light differs (sky"
                t" {h[0] == e.sky}, block {h[1] == e.block})"
            )
    for p in st.probes:
        var pos = Pos(p.x, p.y, p.z)
        var place = String(t"{s.name} step {step} at {pos}")
        assert_equal(w.light(pos), p.light, place)
        assert_equal(w.sky_light(pos), p.sky, place)
        assert_equal(w.block_light(pos), p.block, place)


def test_world_light_matches_dragonfly() raises:
    var br = ArcPointer(vanilla_block_registry())
    for ref s in load_scenarios():
        var w = _world(br, s)
        for pos in s.order:
            _ = w.block(Pos(Int(pos.x()) << 4, 0, Int(pos.z()) << 4))
        _check(w, s, 0)
        for step in range(1, len(s.steps)):
            for op in s.steps[step].ops:
                for b in op.blocks():
                    assert_true(s.chunk_index(b[0], b[2]) >= 0)
                    assert_equal(b[3], 0)
                    w.set_block_runtime_id(Pos(b[0], b[1], b[2]), b[4])
            _check(w, s, step)


def test_light_outside_the_world_and_unloaded_chunks() raises:
    var br = ArcPointer(vanilla_block_registry())
    var s = load_scenarios()[0].copy()
    var w = _world(br, s)
    assert_equal(w.light(Pos(0, 400, 0)), 15)
    assert_equal(w.sky_light(Pos(0, 400, 0)), 15)
    assert_equal(w.block_light(Pos(0, 400, 0)), 0)
    assert_equal(w.light(Pos(0, -65, 0)), 0)
    # Light does not load chunks; SkyLight does.
    assert_equal(w.light(Pos(0, 0, 0)), 0)
    assert_true(not w.chunk_loaded(ChunkPos(0, 0)))
    assert_equal(w.sky_light(Pos(0, 0, 0)), 15)
    assert_true(w.chunk_loaded(ChunkPos(0, 0)))
    assert_equal(w.light(Pos(0, 0, 0)), 15)


def test_relight_skips_changes_light_does_not_see() raises:
    # Replacing a block with one that emits and filters the same light
    # leaves the light alone; a torch lights its surroundings at once.
    var br = ArcPointer(vanilla_block_registry())
    var s = load_scenarios()[0].copy()
    var w = _world(br, s)
    _ = w.block(Pos(0, 0, 0))
    var stone = br[].block_runtime_id(Stone())
    w.set_block_runtime_id(Pos(3, -61, 3), stone)
    assert_equal(w.sky_light(Pos(3, -60, 3)), 15)
    w.set_block_runtime_id(Pos(3, -55, 3), br[].block_runtime_id(Torch()))
    assert_equal(w.block_light(Pos(3, -55, 3)), 14)
    assert_equal(w.block_light(Pos(5, -55, 3)), 12)
    w.set_block_runtime_id(Pos(3, -55, 3), br[].air_runtime_id())
    assert_equal(w.block_light(Pos(5, -55, 3)), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
