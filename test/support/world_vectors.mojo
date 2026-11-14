"""The chunks `interop/world/main.go` builds, rebuilt here step for step, and
the vectors it wrote for them."""

from ignis.block.bedrock import Bedrock
from ignis.block.dirt import Dirt
from ignis.block.grass import Grass
from ignis.block.stone import Stone
from ignis.world.biome.plains import Plains
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.chunk.chunk import Chunk
from ignis.world.dimension import OVERWORLD
from ignis.world.generator import Generator
from ignis.world.generator.flat import Flat
from ignis.world.position import ChunkPos
from std.collections import Dict


def widths() -> List[Int]:
    """The bits per index of the mixed chunk's sub-chunks."""
    return [1, 2, 3, 4, 5, 6, 8, 16]


def load_vectors() raises -> Dict[String, String]:
    var out = Dict[String, String]()
    with open("test/data/world/vectors.txt", "r") as f:
        # splitlines() also splits on tabs in Mojo 1.2.
        for line in f.read().split("\n"):
            if line.byte_length() == 0:
                continue
            var parts = line.split(" ", 1)
            out[String(parts[0])] = String(parts[1])
    return out^


def new_chunk(br: BasicBlockRegistry) -> Chunk:
    return Chunk(br, OVERWORLD.range())


def rids(br: BasicBlockRegistry, n: Int) -> List[UInt32]:
    var count = UInt32(br.block_count())
    var out = List[UInt32]()
    var k = UInt32(0)
    while len(out) < n:
        var rid = (k * 131 + 7) % count
        k += 1
        if rid != br.air_runtime_id() and rid not in out:
            out.append(rid)
    return out^


def mixed_chunk(br: BasicBlockRegistry) -> Chunk:
    var c = new_chunk(br)
    var ws = widths()
    for i in range(len(ws)):
        var w = ws[i]
        var d = (1 << w) - 1
        if w == 16:
            d = 300
        var values = rids(br, d)
        var base = c.sub_y(Int16(i))
        for x in range(16):
            for y in range(16):
                for z in range(16):
                    var k = (x * 31 + y * 17 + z * 5) % d
                    c.set_block(
                        UInt8(x), base + Int16(y), UInt8(z), 0, values[k]
                    )
    var water = rids(br, 1)[0]
    var base = c.sub_y(Int16(len(ws) - 1))
    var x = 0
    while x < 16:
        c.set_block(UInt8(x), base + Int16(x), UInt8(15 - x), 1, water)
        x += 3
    return c^


def simple_chunk(br: BasicBlockRegistry) -> Chunk:
    var c = new_chunk(br)
    var stone = br.block_runtime_id(Stone())
    var dirt = br.block_runtime_id(Dirt())
    var grass = br.block_runtime_id(Grass())
    var bedrock = br.block_runtime_id(Bedrock())
    for x in range(16):
        for z in range(16):
            var h = Int16(-64 + x * 9 + z * 3)
            c.set_block(UInt8(x), -64, UInt8(z), 0, bedrock)
            var y = Int16(-63)
            while y <= h:
                c.set_block(UInt8(x), y, UInt8(z), 0, stone)
                y += 1
            if (x + z) % 4 == 0:
                c.set_block(UInt8(x), h + 1, UInt8(z), 0, dirt)
                c.set_block(UInt8(x), h + 2, UInt8(z), 0, grass)
    c.set_block(3, 300, 4, 0, stone)
    return c^


def biome_chunk(br: BasicBlockRegistry) -> Chunk:
    var c = new_chunk(br)
    for x in range(16):
        for y in range(16):
            for z in range(16):
                c.set_biome(
                    UInt8(x),
                    Int16(-64 + y),
                    UInt8(z),
                    UInt32((x + z * 2 + y // 4) % 5),
                )
    var sec = List[UInt32](length=64, fill=0)
    for x in range(4):
        for y in range(4):
            for z in range(4):
                sec[x * 16 + y * 4 + z] = UInt32(1 + (x + y + z) % 3)
    c.set_biome_section(-48, sec)
    c.set_biome_section(-32, sec)
    c.set_biome_section(-16, List[UInt32](length=64, fill=7))
    for x in range(16):
        for z in range(16):
            c.set_biome(UInt8(x), 0, UInt8(z), UInt32((x * 16 + z) % 70))
    return c^


def flat_layers(br: BasicBlockRegistry) -> List[UInt32]:
    return [
        br.block_runtime_id(Grass()),
        br.block_runtime_id(Dirt()),
        br.block_runtime_id(Dirt()),
        br.block_runtime_id(Bedrock()),
    ]


def flat_chunk(br: BasicBlockRegistry) -> Chunk:
    """Ignis's flat chunk, which matches Go's `flatChunk(true)`."""
    var c = new_chunk(br)
    Flat(Plains(), flat_layers(br)).generate_chunk(ChunkPos(0, 0), c)
    return c^


def flat_chunk_dragonfly(br: BasicBlockRegistry) -> Chunk:
    """Dragonfly v0.11.6's flat chunk: biomes above y 255 left at 0."""
    var c = new_chunk(br)
    var layers = flat_layers(br)
    for x in range(16):
        for z in range(16):
            for y in range(4):
                c.set_block(
                    UInt8(x), Int16(-64 + y), UInt8(z), 0, layers[3 - y]
                )
            for y in range(-64, 256):
                c.set_biome(UInt8(x), Int16(y), UInt8(z), 1)
    return c^
