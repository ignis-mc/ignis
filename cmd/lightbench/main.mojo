"""Times the light engine on the `flat` and `terrain` scenarios of
`test/data/light/vectors.txt`: `Fill` for one chunk column, `Spread` over a
3x3 area, and `relight` after a block change. Compare with
`(cd interop/light && go run . -bench)`.

Build and run from the repository root:

    mojo build --fp-mode contract=off -I src -I test \\
        -I third_party/protocol/src -I third_party/nethernet/src \\
        cmd/lightbench/main.mojo -o build/lightbench && build/lightbench
"""

from std.time import perf_counter_ns

from ignis.block.register import vanilla_block_registry
from ignis.block.stone import Stone
from ignis.block.torch import Torch
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.chunk.chunk import Chunk
from ignis.world.chunk.light import relight
from ignis.world.chunk.light_area import ChunkPointer, LightArea, chunk_pointer
from ignis.world.position import ChunkPos
from support.light_vectors import Scenario, build_chunks, load_scenarios


def _index(s: Scenario, x: Int, z: Int) -> Int:
    for i in range(len(s.order)):
        if s.order[i] == ChunkPos(Int32(x), Int32(z)):
            return i
    return -1


def _fill(br: BasicBlockRegistry, mut c: Chunk, x: Int, z: Int):
    var one = List[ChunkPointer]()
    one.append(chunk_pointer(c))
    var a = LightArea(br, one^, x, z)
    a.fill()


def _area(
    br: BasicBlockRegistry, s: Scenario, mut cs: List[Chunk]
) -> LightArea[BasicBlockRegistry]:
    var ptrs = List[ChunkPointer]()
    for z in range(-1, 2):
        for x in range(-1, 2):
            ptrs.append(chunk_pointer(cs[_index(s, x, z)]))
    return LightArea(br, ptrs^, -1, -1)


def main() raises:
    var br = vanilla_block_registry()
    var torch = br.block_runtime_id(Torch())
    var stone = br.block_runtime_id(Stone())
    comptime N = 200
    for ref s in load_scenarios():
        if s.name != "flat" and s.name != "terrain":
            continue
        var base = build_chunks(s, br.air_runtime_id())
        var centre = _index(s, 0, 0)
        var fill_ns = 0
        var spread_ns = 0
        for _ in range(N):
            var cs = base.copy()
            for i in range(len(cs)):
                if i != centre:
                    _fill(br, cs[i], Int(s.order[i].x()), Int(s.order[i].z()))
            var start = perf_counter_ns()
            _fill(br, cs[centre], 0, 0)
            fill_ns += Int(perf_counter_ns() - start)
            var a = _area(br, s, cs)
            start = perf_counter_ns()
            a.spread()
            spread_ns += Int(perf_counter_ns() - start)
            # The area's pointers do not keep the chunks alive.
            _ = len(cs)
        # Relight: a torch placed and removed in the open, and a stone
        # placed and removed on the surface (a height map change).
        var cs = base.copy()
        for i in range(len(cs)):
            _fill(br, cs[i], Int(s.order[i].x()), Int(s.order[i].z()))
        var a = _area(br, s, cs)
        a.spread()
        var y = Int(cs[centre].height_at(br, 8, 8))
        var relight_ns = 0
        var n = 0
        for _ in range(N):
            for rid in [torch, br.air_runtime_id(), stone, br.air_runtime_id()]:
                var old = Int(cs[centre].height_at(br, 8, 8))
                cs[centre].set_block(8, Int16(y + 1), 8, 0, rid)
                cs[centre].update_height_map_column(br, 8, 8)
                var start = perf_counter_ns()
                relight(a, 8, y + 1, 8, old)
                relight_ns += Int(perf_counter_ns() - start)
                n += 1
        _ = len(cs)
        print(
            s.name,
            ": Fill",
            Float64(fill_ns) / N / 1000,
            "us per chunk column, Spread",
            Float64(spread_ns) / N / 1000,
            "us per 3x3 area, relight",
            Float64(relight_ns) / Float64(n) / 1000,
            "us per block change",
        )
