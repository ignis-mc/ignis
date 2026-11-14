"""The scenarios `interop/light/main.go` lights with Dragonfly, parsed from
`test/data/light/vectors.txt`, and helpers to build and hash them."""

from ignis.world.chunk.chunk import Chunk
from ignis.world.dimension import OVERWORLD
from ignis.world.position import ChunkPos


@fieldwise_init
struct Op(Copyable):
    """A `fill`, `sphere` or `columns` line: blocks placed in a box, a ball
    or a row of terrain columns."""

    var kind: String
    var ints: List[Int]
    """`fill`: x0 y0 z0 x1 y1 z1 layer rid; `sphere`: x y z r rid;
    `columns`: x z0 stone dirt grass water h..."""

    def blocks(self) -> List[Tuple[Int, Int, Int, UInt8, UInt32]]:
        """Returns every position the op sets, in the Go program's order,
        with its layer and runtime ID."""
        var out = List[Tuple[Int, Int, Int, UInt8, UInt32]]()
        ref v = self.ints
        if self.kind == "fill":
            for x in range(v[0], v[3] + 1):
                for y in range(v[1], v[4] + 1):
                    for z in range(v[2], v[5] + 1):
                        out.append((x, y, z, UInt8(v[6]), UInt32(v[7])))
        elif self.kind == "sphere":
            var r = v[3]
            for x in range(v[0] - r, v[0] + r + 1):
                for y in range(v[1] - r, v[1] + r + 1):
                    for z in range(v[2] - r, v[2] + r + 1):
                        var dx = x - v[0]
                        var dy = y - v[1]
                        var dz = z - v[2]
                        if dx * dx + dy * dy + dz * dz <= r * r:
                            out.append((x, y, z, UInt8(0), UInt32(v[4])))
        else:
            var x = v[0]
            var stone = UInt32(v[2])
            var dirt = UInt32(v[3])
            var grass = UInt32(v[4])
            var water = UInt32(v[5])
            for i in range(6, len(v)):
                var h = v[i]
                var z = v[1] + i - 6
                for y in range(OVERWORLD.range().min() + 1, max(h, 54) + 1):
                    if y <= h - 3:
                        out.append((x, y, z, UInt8(0), stone))
                    elif y <= h - 1:
                        out.append((x, y, z, UInt8(0), dirt))
                    elif y == h and h >= 55:
                        out.append((x, y, z, UInt8(0), grass))
                    elif y >= h and h < 55:
                        out.append((x, y, z, UInt8(0), water))
        return out^


@fieldwise_init
struct Expected(Copyable):
    """The light of one chunk after a step: the FNV-1a 64 hash of its sky
    light arrays and of its block light arrays."""

    var pos: ChunkPos
    var sky: UInt64
    var block: UInt64


@fieldwise_init
struct Probe(Copyable):
    """Dragonfly's `Light`, `SkyLight` and `BlockLight` at a position."""

    var x: Int
    var y: Int
    var z: Int
    var light: UInt8
    var sky: UInt8
    var block: UInt8


@fieldwise_init
struct Step(Copyable):
    """Block changes (none for step 0) and the light after them."""

    var ops: List[Op]
    var expected: List[Expected]
    var probes: List[Probe]


@fieldwise_init
struct Scenario(Copyable):
    """Chunks loaded in `order` with the blocks of `build`, then `steps`."""

    var name: String
    var order: List[ChunkPos]
    var build: List[Op]
    var steps: List[Step]

    def chunk_index(self, x: Int, z: Int) -> Int:
        """Returns the index in `order` of the chunk holding a block, or
        -1."""
        var pos = ChunkPos(Int32(x >> 4), Int32(z >> 4))
        for i in range(len(self.order)):
            if self.order[i] == pos:
                return i
        return -1


def _ints(parts: List[String], start: Int) raises -> List[Int]:
    var out = List[Int]()
    for i in range(start, len(parts)):
        out.append(Int(parts[i]))
    return out^


def _hex(s: String) raises -> UInt64:
    var v = UInt64(0)
    for byte in s.as_bytes():
        var b = Int(byte)
        var d: UInt64
        if b >= ord("0") and b <= ord("9"):
            d = UInt64(b - ord("0"))
        elif b >= ord("a") and b <= ord("f"):
            d = UInt64(b - ord("a") + 10)
        else:
            raise Error("bad hex digit in ", s)
        v = (v << 4) | d
    return v


def load_scenarios() raises -> List[Scenario]:
    """Parses `test/data/light/vectors.txt`."""
    var out = List[Scenario]()
    var text: String
    with open("test/data/light/vectors.txt", "r") as f:
        text = f.read()
    var name = String()
    var order = List[ChunkPos]()
    var build = List[Op]()
    var steps = List[Step]()
    var ops = List[Op]()
    var expected = List[Expected]()
    var probes = List[Probe]()
    for line in text.split("\n"):
        if line.byte_length() == 0 or line.startswith("#"):
            continue
        var parts = List[String]()
        for p in line.split(" "):
            parts.append(String(p))
        var kind = parts[0]
        if kind == "scenario":
            name = parts[1]
        elif kind == "load":
            order.append(ChunkPos(Int32(Int(parts[1])), Int32(Int(parts[2]))))
        elif kind == "fill" or kind == "sphere" or kind == "columns":
            var op = Op(kind, _ints(parts, 1))
            if len(steps) == 0 and len(expected) == 0:
                build.append(op^)
            else:
                ops.append(op^)
        elif kind == "light":
            expected.append(
                Expected(
                    ChunkPos(Int32(Int(parts[2])), Int32(Int(parts[3]))),
                    _hex(parts[4]),
                    _hex(parts[5]),
                )
            )
        elif kind == "probe":
            var v = _ints(parts, 2)
            probes.append(
                Probe(v[0], v[1], v[2], UInt8(v[3]), UInt8(v[4]), UInt8(v[5]))
            )
        elif kind == "step" or kind == "end":
            steps.append(Step(ops^, expected^, probes^))
            ops = List[Op]()
            expected = List[Expected]()
            probes = List[Probe]()
            if kind == "end":
                out.append(Scenario(name, order^, build^, steps^))
                order = List[ChunkPos]()
                build = List[Op]()
                steps = List[Step]()
    return out^


def build_chunks(s: Scenario, air: UInt32) -> List[Chunk]:
    """Builds the scenario's chunks, in load order, from its build ops."""
    var cs = List[Chunk]()
    for _ in range(len(s.order)):
        cs.append(Chunk(air, OVERWORLD.range()))
    var r = OVERWORLD.range()
    for op in s.build:
        for b in op.blocks():
            var i = s.chunk_index(b[0], b[2])
            if i < 0 or b[1] < r.min() or b[1] > r.max():
                continue
            cs[i].set_block(
                UInt8(b[0] & 0xF), Int16(b[1]), UInt8(b[2] & 0xF), b[3], b[4]
            )
    return cs^


def fnv64(data: List[UInt8]) -> UInt64:
    """Returns the FNV-1a 64 hash of the bytes."""
    var h = UInt64(0xCBF29CE484222325)
    for b in data:
        h ^= UInt64(b)
        h *= 0x100000001B3
    return h


def light_hashes(c: Chunk) -> Tuple[UInt64, UInt64]:
    """Returns the hashes of a chunk's sky and block light arrays, as the
    Go program writes them."""
    var sky = List[UInt8]()
    var block = List[UInt8]()
    for i in range(len(c.sub())):
        sky.extend(c.sub()[i].sky_light_array().bytes())
        block.extend(c.sub()[i].block_light_array().bytes())
    return (fnv64(sky), fnv64(block))
