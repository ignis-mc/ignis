from ignis.block.cube.pos import Pos
from ignis.block.register import vanilla_block_registry
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.chunk.chunk import Chunk
from ignis.world.chunk.light import relight
from ignis.world.chunk.light_area import ChunkPointer, LightArea, chunk_pointer
from ignis.world.position import ChunkPos
from std.testing import TestSuite, assert_equal, assert_true
from support.light_vectors import (
    Scenario,
    build_chunks,
    light_hashes,
    load_scenarios,
)


def _index(s: Scenario, x: Int32, z: Int32) -> Int:
    for i in range(len(s.order)):
        if s.order[i] == ChunkPos(x, z):
            return i
    return -1


def _area(
    br: BasicBlockRegistry, s: Scenario, mut cs: List[Chunk], centre: ChunkPos
) -> Optional[LightArea[BasicBlockRegistry]]:
    # The 3x3 chunks around centre, or None if one is missing.
    var ptrs = List[ChunkPointer]()
    for dz in range(-1, 2):
        for dx in range(-1, 2):
            var i = _index(s, centre.x() + Int32(dx), centre.z() + Int32(dz))
            if i < 0:
                return None
            ptrs.append(chunk_pointer(cs[i]))
    return LightArea(br, ptrs^, Int(centre.x()) - 1, Int(centre.z()) - 1)


def _load_in_order(br: BasicBlockRegistry, s: Scenario, mut cs: List[Chunk]):
    # World.loadChunk and World.addChunk: Fill each chunk as it loads, then
    # Spread every loaded chunk whose 3x3 neighbourhood is now complete.
    var loaded = List[Bool](length=len(cs), fill=False)
    for i in range(len(s.order)):
        var pos = s.order[i]
        var one = List[ChunkPointer]()
        one.append(chunk_pointer(cs[i]))
        var area = LightArea(br, one^, Int(pos.x()), Int(pos.z()))
        area.fill()
        loaded[i] = True
        for dx in range(-1, 2):
            for dz in range(-1, 2):
                var p = ChunkPos(pos.x() + Int32(dx), pos.z() + Int32(dz))
                var j = _index(s, p.x(), p.z())
                if j < 0 or not loaded[j]:
                    continue
                var complete = True
                for ex in range(-1, 2):
                    for ez in range(-1, 2):
                        var k = _index(s, p.x() + Int32(ex), p.z() + Int32(ez))
                        if k < 0 or not loaded[k]:
                            complete = False
                if complete:
                    var a = _area(br, s, cs, p)
                    a.value().spread()


def _check(s: Scenario, step: Int, cs: List[Chunk]) raises:
    ref st = s.steps[step]
    for e in st.expected:
        var i = _index(s, e.pos.x(), e.pos.z())
        var h = light_hashes(cs[i])
        if h[0] != e.sky or h[1] != e.block:
            raise Error(
                t"{s.name} step {step}: chunk {e.pos} light differs (sky"
                t" {h[0] == e.sky}, block {h[1] == e.block})"
            )
    for p in st.probes:
        ref c = cs[_index(s, Int32(p.x >> 4), Int32(p.z >> 4))]
        var x = UInt8(p.x & 0xF)
        var z = UInt8(p.z & 0xF)
        var y = Int16(p.y)
        assert_equal(
            c.light(x, y, z), p.light, String(t"{s.name} {step} light")
        )
        assert_equal(
            c.sky_light(x, y, z), p.sky, String(t"{s.name} {step} sky")
        )
        assert_equal(
            c.block_light(x, y, z), p.block, String(t"{s.name} {step} block")
        )


def _set_block(
    br: BasicBlockRegistry,
    s: Scenario,
    mut cs: List[Chunk],
    x: Int,
    y: Int,
    z: Int,
    rid: UInt32,
):
    # What World.set_block_runtime_id does for light.
    var i = s.chunk_index(x, z)
    if i < 0:
        return
    var ux = UInt8(x & 0xF)
    var uz = UInt8(z & 0xF)
    var old = Int(cs[i].height_at(br, ux, uz))
    cs[i].set_block(ux, Int16(y), uz, 0, rid)
    cs[i].update_height_map_column(br, ux, uz)
    var centre = s.order[i]
    var ptrs = List[ChunkPointer]()
    var absent = List[Int]()
    for dz in range(-1, 2):
        for dx in range(-1, 2):
            var j = _index(s, centre.x() + Int32(dx), centre.z() + Int32(dz))
            if j < 0:
                absent.append(len(ptrs))
                j = i
            ptrs.append(chunk_pointer(cs[j]))
    var a = LightArea(br, ptrs^, Int(centre.x()) - 1, Int(centre.z()) - 1)
    for k in absent:
        a.set_absent(k)
    relight(a, x, y, z, old)


def test_scenarios_match_dragonfly() raises:
    var br = vanilla_block_registry()
    var scenarios = load_scenarios()
    assert_true(len(scenarios) >= 6)
    for ref s in scenarios:
        var cs = build_chunks(s, br.air_runtime_id())
        _load_in_order(br, s, cs)
        _check(s, 0, cs)
        for step in range(1, len(s.steps)):
            for op in s.steps[step].ops:
                for b in op.blocks():
                    _set_block(br, s, cs, b[0], b[1], b[2], b[4])
            _check(s, step, cs)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
