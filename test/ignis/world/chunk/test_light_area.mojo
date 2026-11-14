from ignis.block.glowstone import Glowstone
from ignis.block.register import vanilla_block_registry
from ignis.block.stone import Stone
from ignis.world.chunk.chunk import Chunk
from ignis.world.chunk.light import node
from ignis.world.chunk.light_area import (
    ChunkPointer,
    LightArea,
    LightQueue,
    chunk_pointer,
)
from ignis.world.chunk.light_type import BLOCK_LIGHT, SKY_LIGHT
from ignis.world.dimension import OVERWORLD
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_queue_is_fifo_and_grows() raises:
    var q = LightQueue(2)
    for i in range(5):
        q.push(node(i, 0, 0, 1, BLOCK_LIGHT))
    _ = q.pop()
    for i in range(5, 9):
        q.push(node(i, 0, 0, 1, BLOCK_LIGHT))
    for i in range(1, 9):
        assert_false(q.empty())
        assert_equal(Int(q.pop().x), i)
    assert_true(q.empty())


def test_fill_lights_an_empty_chunk_with_the_sky() raises:
    var br = vanilla_block_registry()
    var c = Chunk(br, OVERWORLD.range())
    var ptrs = List[ChunkPointer]()
    ptrs.append(chunk_pointer(c))
    var a = LightArea(br, ptrs^, 0, 0)
    a.fill()
    assert_equal(c.sky_light(3, -64, 4), 15)
    assert_equal(c.sky_light(3, 319, 4), 15)
    assert_equal(c.light(3, 0, 4), 15)
    assert_equal(c.block_light(3, 0, 4), 0)


def test_spread_crosses_borders_in_the_top_sub_chunk() raises:
    # Dragonfly's iterEdges stops below the top sub-chunk, so this tunnel
    # stayed dark past the border; Ignis spreads it.
    var br = vanilla_block_registry()
    var stone = br.block_runtime_id(Stone())
    var air = br.air_runtime_id()
    var cs = List[Chunk]()
    for _ in range(4):
        cs.append(Chunk(br, OVERWORLD.range()))
    for i in range(4):
        for x in range(16):
            for z in range(16):
                for y in range(304, 320):
                    cs[i].set_block(UInt8(x), Int16(y), UInt8(z), 0, stone)
    for x in range(10, 16):
        cs[0].set_block(UInt8(x), 310, 5, 0, air)
    for x in range(0, 6):
        cs[1].set_block(UInt8(x), 310, 5, 0, air)
    cs[0].set_block(10, 310, 5, 0, br.block_runtime_id(Glowstone()))
    for i in range(4):
        var one = List[ChunkPointer]()
        one.append(chunk_pointer(cs[i]))
        var a = LightArea(br, one^, i % 2, i // 2)
        a.fill()
    assert_equal(cs[0].block_light(15, 310, 5), 10)
    assert_equal(cs[1].block_light(0, 310, 5), 0)
    var ptrs = List[ChunkPointer]()
    for i in range(4):
        ptrs.append(chunk_pointer(cs[i]))
    var area = LightArea(br, ptrs^, 0, 0)
    area.spread()
    assert_equal(cs[1].block_light(0, 310, 5), 9)
    assert_equal(cs[1].block_light(5, 310, 5), 4)
    assert_equal(cs[1].sky_light(0, 310, 5), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
