"""The light engine, ported from Dragonfly `server/world/chunk/light.go`,
`light_area.go` and `light_type.go`.

Go's `lightArea` holds pointers to the chunks it lights; here the functions
take the chunks as a list the caller moves in and out (`fill_light`,
`spread_light`). Go shares two 2048-byte arrays for sub-chunks that are fully
lit or fully dark and copies them on the first write; a sub-chunk here
records that state in a flag instead (`LIGHT_NONE`, `LIGHT_FULL`), which is
what `nodesNeeded` compares.
"""

from ...block.cube.pos import Pos
from ...block.cube.range import Range
from .block_registry import BlockRegistry
from .chunk import Chunk
from .sub_chunk import LIGHT_FULL, LIGHT_NONE, LIGHT_OWN, SubChunk

comptime SKY_LIGHT = 0
"""Go `SkyLight`."""
comptime BLOCK_LIGHT = 1
"""Go `BlockLight`."""


@fieldwise_init
struct _LightNode(ImplicitlyCopyable):
    # Go `lightNode`.
    var pos: Pos
    var lt: Int
    var level: UInt8


struct _LightQueue(Movable):
    # Go `lightQueue`: a FIFO; Go's ring buffer is a list with a head index.
    var nodes: List[_LightNode]
    var head: Int

    def __init__(out self):
        self.nodes = List[_LightNode](capacity=1024)
        self.head = 0

    def push(mut self, n: _LightNode):
        self.nodes.append(n)

    def pop(mut self) -> _LightNode:
        var n = self.nodes[self.head]
        self.head += 1
        if self.head == len(self.nodes):
            self.nodes.clear()
            self.head = 0
        return n

    def empty(self) -> Bool:
        return self.head == len(self.nodes)


struct _Area:
    # Go `lightArea` without the chunks.
    var base_x: Int
    var base_z: Int
    var w: Int
    var r: Range

    def __init__(out self, n: Int, base_x: Int, base_z: Int, r: Range):
        var w = 1
        while w * w < n:
            w += 1
        self.w = w
        self.base_x = base_x << 4
        self.base_z = base_z << 4
        self.r = r

    def chunk_index(self, pos: Pos) -> Int:
        var x = (pos.x() - self.base_x) >> 4
        var z = (pos.z() - self.base_z) >> 4
        return x + z * self.w


def _sub(ref c: List[Chunk], a: _Area, pos: Pos) -> ref[c[0]._sub[0]] SubChunk:
    ref ch = c[a.chunk_index(pos)]
    return ch._sub[Int(ch.sub_index(Int16(pos.y())))]


def _light(ref c: List[Chunk], a: _Area, pos: Pos, lt: Int) -> UInt8:
    ref sub = _sub(c, a, pos)
    var x = UInt8(pos.x() & 0xF)
    var y = UInt8(pos.y() & 0xF)
    var z = UInt8(pos.z() & 0xF)
    if lt == SKY_LIGHT:
        return sub.sky_light(x, y, z)
    return sub.block_light(x, y, z)


def _set_light(mut c: List[Chunk], a: _Area, pos: Pos, lt: Int, v: UInt8):
    ref sub = _sub(c, a, pos)
    var x = UInt8(pos.x() & 0xF)
    var y = UInt8(pos.y() & 0xF)
    var z = UInt8(pos.z() & 0xF)
    if lt == SKY_LIGHT:
        sub.set_sky_light(x, y, z, v)
    else:
        sub.set_block_light(x, y, z, v)


def _highest[
    R: BlockRegistry, filtering: Bool
](br: R, ref c: List[Chunk], a: _Area, pos: Pos) -> UInt8:
    # Go `highest`: the highest light filter (or emission) of both layers.
    ref sub = _sub(c, a, pos)
    var x = UInt8(pos.x() & 0xF)
    var y = UInt8(pos.y() & 0xF)
    var z = UInt8(pos.z() & 0xF)
    ref storages = sub.layers()
    var n = len(storages)
    if n == 0:
        return 0
    var level = _block_value[R, filtering](br, storages[0].at(x, y, z))
    if n == 1:
        return level
    return max(level, _block_value[R, filtering](br, storages[1].at(x, y, z)))


def _block_value[
    R: BlockRegistry, filtering: Bool
](br: R, rid: UInt32) -> UInt8:
    comptime if filtering:
        return br.filtering_block(rid)
    else:
        return br.light_block(rid)


def fill_light[
    R: BlockRegistry
](br: R, mut c: List[Chunk], base_x: Int, base_z: Int):
    """Calculates the light of one chunk on its own (Go
    `LightArea(...).Fill`)."""
    var a = _Area(len(c), base_x, base_z, c[0].range())
    _initialise_light_slices(c)
    var queue = _LightQueue()
    _insert_block_light_nodes(br, c, a, queue)
    _insert_sky_light_nodes(br, c, a, queue)
    while not queue.empty():
        _propagate(br, c, a, queue)


def spread_light[
    R: BlockRegistry
](br: R, mut c: List[Chunk], base_x: Int, base_z: Int):
    """Spreads light between the chunks of a 3x3 area, listed row by row
    from (`base_x`, `base_z`) (Go `LightArea(...).Spread`)."""
    var a = _Area(len(c), base_x, base_z, c[0].range())
    var queue = _LightQueue()
    _insert_light_spreading_nodes(br, c, a, queue, BLOCK_LIGHT)
    _insert_light_spreading_nodes(br, c, a, queue, SKY_LIGHT)
    while not queue.empty():
        _propagate(br, c, a, queue)


def _initialise_light_slices(mut c: List[Chunk]):
    # Go `initialiseLightSlices`: empty sub-chunks above the highest filled
    # one are fully sky-lit, everything else starts dark.
    for i in range(len(c)):
        var index = len(c[i]._sub) - 1
        while index >= 0:
            if not c[i]._sub[index].empty():
                break
            c[i]._sub[index].reset_light(LIGHT_FULL, LIGHT_NONE)
            index -= 1
        while index >= 0:
            c[i]._sub[index].reset_light(LIGHT_NONE, LIGHT_NONE)
            index -= 1


def _insert_block_light_nodes[
    R: BlockRegistry
](br: R, mut c: List[Chunk], a: _Area, mut queue: _LightQueue):
    # Go `insertBlockLightNodes`, with `iterSubChunks`.
    for cx in range(a.w):
        for cz in range(a.w):
            var base_x = a.base_x + (cx << 4)
            var base_z = a.base_z + (cz << 4)
            var ci = cx + cz * a.w
            for index in range(len(c[ci]._sub)):
                if not _any_light_blocks(br, c[ci]._sub[index]):
                    continue
                var base_y = Int(c[ci].sub_y(Int16(index)))
                for y in range(16):
                    for x in range(16):
                        for z in range(16):
                            var pos = Pos(x + base_x, y + base_y, z + base_z)
                            var level = _highest[R, False](br, c, a, pos)
                            if level > 0:
                                queue.push(_LightNode(pos, BLOCK_LIGHT, level))


def _any_light_blocks[R: BlockRegistry](br: R, sub: SubChunk) -> Bool:
    # Go `anyLightBlocks`.
    for ref layer in sub.layers():
        for id in layer._palette._values:
            if br.light_block(id) != 0:
                return True
    return False


def _insert_sky_light_nodes[
    R: BlockRegistry
](br: R, mut c: List[Chunk], a: _Area, mut queue: _LightQueue):
    # Go `insertSkyLightNodes`, with `iterHeightmap`.
    var m = c[0].height_map(br)
    var highest_y = c[0].range().min()
    var lowest_y = highest_y
    for index in range(len(c[0]._sub)):
        if c[0]._sub[index].empty():
            continue
        highest_y = Int(c[0].sub_y(Int16(index))) + 15
    for ux in range(16):
        for uz in range(16):
            var x = ux + a.base_x
            var z = uz + a.base_z
            var height = Int(m.at(UInt8(ux), UInt8(uz)))
            var highest_neighbour = Int(
                m.highest_neighbour(UInt8(ux), UInt8(uz))
            )
            var pos = Pos(x, height, z)
            if height <= a.r.max():
                # Only set light below the top of the world.
                _set_light(c, a, pos, SKY_LIGHT, 15)
                if pos.y() > lowest_y:
                    var level = _highest[R, True](
                        br, c, a, Pos(x, height - 1, z)
                    )
                    if level != 15 and level != 0:
                        # A block like water or leaves diffuses but does
                        # not block light: it needs a node above it.
                        queue.push(_LightNode(pos, SKY_LIGHT, 15))
            var y = pos.y()
            while y < highest_y:
                y += 1
                var p = Pos(x, y, z)
                if y < highest_neighbour:
                    queue.push(_LightNode(p, SKY_LIGHT, 15))
                    continue
                # Fill the rest with full skylight.
                _set_light(c, a, p, SKY_LIGHT, 15)


def _insert_light_spreading_nodes[
    R: BlockRegistry
](br: R, mut c: List[Chunk], a: _Area, mut queue: _LightQueue, lt: Int):
    # Go `insertLightSpreadingNodes`, with `iterEdges` and `nodesNeeded`.
    var min_y = a.r.min() >> 4
    var max_y = a.r.max() >> 4
    for cu in range(1, a.w):
        var u = cu << 4
        for cv in range(a.w):
            var v = cv << 4
            for cy in range(min_y, max_y):
                var base_y = cy << 4
                var xa = Pos(a.base_x + u, base_y, a.base_z + v)
                var za = Pos(a.base_x + v, base_y, a.base_z + u)
                var xb = Pos(xa.x() - 1, xa.y(), xa.z())
                var zb = Pos(za.x(), za.y(), za.z() - 1)
                var add_x = _nodes_needed(
                    _sub(c, a, xa).light_kind(lt), _sub(c, a, xb).light_kind(lt)
                )
                var add_z = _nodes_needed(
                    _sub(c, a, za).light_kind(lt), _sub(c, a, zb).light_kind(lt)
                )
                if not add_x and not add_z:
                    continue
                for add_v in range(16):
                    for y in range(16):
                        if add_x:
                            _spread_edge(
                                br,
                                c,
                                a,
                                queue,
                                lt,
                                xa.add(Pos(0, y, add_v)),
                                xb.add(Pos(0, y, add_v)),
                            )
                        if add_z:
                            _spread_edge(
                                br,
                                c,
                                a,
                                queue,
                                lt,
                                za.add(Pos(add_v, y, 0)),
                                zb.add(Pos(add_v, y, 0)),
                            )


def _nodes_needed(ka: UInt8, kb: UInt8) -> Bool:
    # Go `nodesNeeded`: two sub-chunks still sharing the same uniform array
    # cannot spread light into each other.
    return ka == LIGHT_OWN or ka != kb


def _spread_edge[
    R: BlockRegistry
](
    br: R,
    mut c: List[Chunk],
    a: _Area,
    mut queue: _LightQueue,
    lt: Int,
    pa: Pos,
    pb: Pos,
):
    # The function `insertLightSpreadingNodes` passes to `iterEdges`.
    var la = _light(c, a, pa, lt)
    var lb = _light(c, a, pb, lt)
    if la == lb or la - 1 == lb or lb - 1 == la:
        # No chance for this to spread.
        return
    var filter = _highest[R, True](br, c, a, pb) + 1
    if la > filter and la - filter > lb:
        queue.push(_LightNode(pb, lt, la - filter))
        return
    filter = _highest[R, True](br, c, a, pa) + 1
    if lb > filter and lb - filter > la:
        queue.push(_LightNode(pa, lt, lb - filter))


def _propagate[
    R: BlockRegistry
](br: R, mut c: List[Chunk], a: _Area, mut queue: _LightQueue):
    # Go `propagate`.
    var n = queue.pop()
    if _light(c, a, n.pos, n.lt) >= n.level:
        return
    _set_light(c, a, n.pos, n.lt, n.level)
    if n.level == 1:
        # Every neighbour takes at least one level away.
        return
    var x = n.pos.x()
    var y = n.pos.y()
    var z = n.pos.z()
    _propagate_neighbour(br, c, a, queue, n.lt, n.level, x + 1, y, z)
    _propagate_neighbour(br, c, a, queue, n.lt, n.level, x - 1, y, z)
    _propagate_neighbour(br, c, a, queue, n.lt, n.level, x, y + 1, z)
    _propagate_neighbour(br, c, a, queue, n.lt, n.level, x, y - 1, z)
    _propagate_neighbour(br, c, a, queue, n.lt, n.level, x, y, z + 1)
    _propagate_neighbour(br, c, a, queue, n.lt, n.level, x, y, z - 1)


def _propagate_neighbour[
    R: BlockRegistry
](
    br: R,
    mut c: List[Chunk],
    a: _Area,
    mut queue: _LightQueue,
    lt: Int,
    level: UInt8,
    x: Int,
    y: Int,
    z: Int,
):
    # Go `propagateNeighbour`.
    if (
        y < a.r.min()
        or y > a.r.max()
        or x < a.base_x
        or z < a.base_z
        or x >= a.base_x + a.w * 16
        or z >= a.base_z + a.w * 16
    ):
        return
    var pos = Pos(x, y, z)
    var filter = _highest[R, True](br, c, a, pos) + 1
    if level > filter and _light(c, a, pos, lt) < level - filter:
        queue.push(_LightNode(pos, lt, level - filter))
