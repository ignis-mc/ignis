"""Light propagation, ported from Dragonfly `server/world/chunk/light.go`.

Go's `lightArea` methods in `light.go` are free functions here taking the
area first (`propagate(a, queue)` for Go `a.propagate(queue)`), since a Mojo
struct keeps all its methods in one place (`light_area.mojo`).

`relight` is Ignis's: Dragonfly v0.11.6 computes light only when a chunk is
loaded and leaves it stale when blocks change until the chunk is loaded
again. `relight` updates the light around a changed block incrementally
(removing the light that depended on the old block, then spreading again
from what is left and from the new sources) and gives exactly what
Dragonfly's `Fill` and `Spread` compute when the chunks are loaded afresh,
including one Dragonfly quirk: `insert_sky_light_nodes` sets the block at a
column's height map value to 15 without queueing it, so that block never
lights its neighbours in the same chunk (`spread` still carries it into
other chunks). `relight` leaves out the same edges.
"""

from ...block.cube.range import Range
from .block_registry import BlockRegistry
from .light_area import LightArea, LightQueue
from .light_type import BLOCK_LIGHT, SKY_LIGHT
from .sub_chunk import SubChunk


@fieldwise_init
struct LightNode(ImplicitlyCopyable, Movable):
    """A node queued to propagate light (Go `lightNode`)."""

    var x: Int32
    """The block X."""
    var y: Int32
    """The block Y."""
    var z: Int32
    """The block Z."""
    var level: UInt8
    """The light level to spread."""
    var lt: UInt8
    """`SKY_LIGHT` or `BLOCK_LIGHT`."""


@always_inline
def node(x: Int, y: Int, z: Int, level: UInt8, lt: UInt8) -> LightNode:
    """Creates a light node (Go `node`)."""
    return LightNode(Int32(x), Int32(y), Int32(z), level, lt)


def insert_block_light_nodes[
    R: BlockRegistry
](mut a: LightArea[R], mut queue: LightQueue):
    """Queues a node for every block in the area that emits light (Go
    `insertBlockLightNodes`)."""
    for cx in range(a.w):
        for cz in range(a.w):
            var base_x = a.base_x + (cx << 4)
            var base_z = a.base_z + (cz << 4)
            ref c = a.chunk_at(a.chunk_index(cx, cz))
            for index in range(len(c._sub)):
                if not any_light_blocks(a, c._sub[index]):
                    continue
                var base_y = Int(c.sub_y(Int16(index)))
                for y in range(16):
                    for x in range(16):
                        for z in range(16):
                            var px = x + base_x
                            var py = y + base_y
                            var pz = z + base_z
                            var level = a.highest[True](px, py, pz)
                            if level > 0:
                                queue.push(node(px, py, pz, level, BLOCK_LIGHT))


def any_light_blocks[R: BlockRegistry](a: LightArea[R], sub: SubChunk) -> Bool:
    """Reports whether any block in a sub-chunk's palettes emits light (Go
    `anyLightBlocks`)."""
    for i in range(len(sub._storages)):
        ref values = sub._storages[i]._palette._values
        for j in range(len(values)):
            if a.br().light_block(values[j]) != 0:
                return True
    return False


def insert_sky_light_nodes[
    R: BlockRegistry
](mut a: LightArea[R], mut queue: LightQueue):
    """Sets full sky light above the height map of the area's first chunk
    and queues nodes where it can spread sideways (Go
    `insertSkyLightNodes`)."""
    ref c = a.chunk_at(0)
    var m = c.height_map(a.br())
    var highest_y = a.r.min()
    var lowest_y = highest_y
    for index in range(len(c._sub)):
        if c._sub[index].empty():
            continue
        highest_y = Int(c.sub_y(Int16(index))) + 15
    for ux in range(16):
        for uz in range(16):
            var x = ux + a.base_x
            var z = uz + a.base_z
            var height = Int(m.at(UInt8(ux), UInt8(uz)))
            var highest_neighbour = Int(
                m.highest_neighbour(UInt8(ux), UInt8(uz))
            )
            var y = height
            if height <= a.r.max():
                # Only set light if we're not at the top of the world.
                a.set_light(x, y, z, SKY_LIGHT, 15)
                if y > lowest_y:
                    var level = a.highest[False](x, y - 1, z)
                    if level != 15 and level != 0:
                        # Water or leaves below: queue a node regardless of
                        # the neighbours.
                        queue.push(node(x, y, z, 15, SKY_LIGHT))
            for _ in range(height, highest_y):
                # Neighbours lower than this column, or one higher, cannot
                # take light from it; only queue nodes below the highest.
                y += 1
                if y < highest_neighbour:
                    queue.push(node(x, y, z, 15, SKY_LIGHT))
                    continue
                a.set_light(x, y, z, SKY_LIGHT, 15)


def insert_light_spreading_nodes[
    R: BlockRegistry
](mut a: LightArea[R], mut queue: LightQueue, lt: UInt8):
    """Queues nodes at chunk borders inside the area where light of type
    `lt` spreads into the neighbouring chunk (Go
    `insertLightSpreadingNodes`, with `iterEdges` inlined)."""
    var min_y = a.r.min() >> 4
    var max_y = a.r.max() >> 4
    for cu in range(1, a.w):
        var u = cu << 4
        for cv in range(a.w):
            var v = cv << 4
            # Go stops at max_y - 1 and never visits the top sub-chunk.
            for cy in range(min_y, max_y + 1):
                var base_y = cy << 4
                var xax = a.base_x + u
                var xaz = a.base_z + v
                var zax = a.base_x + v
                var zaz = a.base_z + u
                var add_x = nodes_needed(
                    a.sub(xax, base_y, xaz), a.sub(xax - 1, base_y, xaz), lt
                )
                var add_z = nodes_needed(
                    a.sub(zax, base_y, zaz), a.sub(zax, base_y, zaz - 1), lt
                )
                if not add_x and not add_z:
                    continue
                for add_v in range(16):
                    for y in range(16):
                        if add_x:
                            _spread_edge(
                                a,
                                queue,
                                lt,
                                xax,
                                base_y + y,
                                xaz + add_v,
                                xax - 1,
                                xaz + add_v,
                            )
                        if add_z:
                            _spread_edge(
                                a,
                                queue,
                                lt,
                                zax + add_v,
                                base_y + y,
                                zaz,
                                zax + add_v,
                                zaz - 1,
                            )


@always_inline
def _spread_edge[
    R: BlockRegistry
](
    mut a: LightArea[R],
    mut queue: LightQueue,
    lt: UInt8,
    ax: Int,
    y: Int,
    az: Int,
    bx: Int,
    bz: Int,
):
    var la = a.light(ax, y, az, lt)
    var lb = a.light(bx, y, bz, lt)
    if la == lb or la - 1 == lb or lb - 1 == la:
        # No chance for this to spread.
        return
    var filter = a.highest[False](bx, y, bz) + 1
    if la > filter and la - filter > lb:
        queue.push(node(bx, y, bz, la - filter, lt))
        return
    filter = a.highest[False](ax, y, az) + 1
    if lb > filter and lb - filter > la:
        queue.push(node(ax, y, az, lb - filter, lt))


def nodes_needed(sa: SubChunk, sb: SubChunk, lt: UInt8) -> Bool:
    """Reports whether light of type `lt` may spread between two
    neighbouring sub-chunks: not if both still share the same uniform array
    (Go `nodesNeeded`)."""
    if lt == SKY_LIGHT:
        return not sa._sky_light.same_shared(sb._sky_light)
    return not sa._block_light.same_shared(sb._block_light)


def propagate[R: BlockRegistry](mut a: LightArea[R], mut queue: LightQueue):
    """Spreads the next node in the queue, queueing its neighbours for as
    long as light keeps spreading (Go `propagate`)."""
    if queue.empty():
        return
    var n = queue.pop()
    var x = Int(n.x)
    var y = Int(n.y)
    var z = Int(n.z)
    if a.light(x, y, z, n.lt) >= n.level:
        return
    a.set_light(x, y, z, n.lt, n.level)
    if n.level == 1:
        # Every neighbour attenuates light by at least one.
        return
    propagate_neighbour(a, queue, n.lt, n.level, x + 1, y, z)
    propagate_neighbour(a, queue, n.lt, n.level, x - 1, y, z)
    propagate_neighbour(a, queue, n.lt, n.level, x, y + 1, z)
    propagate_neighbour(a, queue, n.lt, n.level, x, y - 1, z)
    propagate_neighbour(a, queue, n.lt, n.level, x, y, z + 1)
    propagate_neighbour(a, queue, n.lt, n.level, x, y, z - 1)


@always_inline
def propagate_neighbour[
    R: BlockRegistry
](
    mut a: LightArea[R],
    mut queue: LightQueue,
    lt: UInt8,
    level: UInt8,
    x: Int,
    y: Int,
    z: Int,
):
    """Queues a neighbour of a node if light spreads into it (Go
    `propagateNeighbour`)."""
    if (
        y < a.r.min()
        or y > a.r.max()
        or x < a.base_x
        or z < a.base_z
        or x >= a.base_x + a.w * 16
        or z >= a.base_z + a.w * 16
    ):
        return
    var filter = a.highest[False](x, y, z) + 1
    if level > filter and a.light(x, y, z, lt) < level - filter:
        queue.push(node(x, y, z, level - filter, lt))


# ===----------------------------------------------------------------------=== #
# Incremental relighting (Ignis)
# ===----------------------------------------------------------------------=== #


# The six neighbours in Go's order: +X, -X, +Y, -Y, +Z, -Z.
def _dx(i: Int) -> Int:
    return 1 if i == 0 else (-1 if i == 1 else 0)


def _dy(i: Int) -> Int:
    return 1 if i == 2 else (-1 if i == 3 else 0)


def _dz(i: Int) -> Int:
    return 1 if i == 4 else (-1 if i == 5 else 0)


def relight[
    R: BlockRegistry
](mut a: LightArea[R], x: Int, y: Int, z: Int, old_height: Int):
    """Updates the light after the block at a position changed, given the
    column's height map value before the change (the chunk's height map
    must already hold the new one).

    The area must reach at least 15 blocks around the position (the 3x3
    chunks around it); chunks not loaded can be marked absent.
    """
    _relight_block(a, x, y, z)
    _relight_sky(a, x, y, z, old_height)


def _relight_block[
    R: BlockRegistry
](mut a: LightArea[R], x: Int, y: Int, z: Int):
    var removal = LightQueue(64)
    var add = LightQueue(64)
    var old = a.light(x, y, z, BLOCK_LIGHT)
    if old > 0:
        a.set_light(x, y, z, BLOCK_LIGHT, 0)
        removal.push(node(x, y, z, old, BLOCK_LIGHT))
    var sources = List[LightNode]()
    sources.append(node(x, y, z, a.highest[True](x, y, z), BLOCK_LIGHT))
    _unspread(a, removal, add, sources, BLOCK_LIGHT)
    for n in sources:
        var sx = Int(n.x)
        var sy = Int(n.y)
        var sz = Int(n.z)
        if n.level > a.light(sx, sy, sz, BLOCK_LIGHT):
            a.set_light(sx, sy, sz, BLOCK_LIGHT, n.level)
            add.push(n)
    _queue_neighbours(a, add, x, y, z, BLOCK_LIGHT)
    _respread(a, add)


def _relight_sky[
    R: BlockRegistry
](mut a: LightArea[R], x: Int, y: Int, z: Int, old_height: Int):
    var removal = LightQueue(64)
    var add = LightQueue(64)
    var height = a.height(x, z)
    var top = a.r.max()
    if y < height:
        # No longer (or still not) open to the sky.
        var old = a.light(x, y, z, SKY_LIGHT)
        if old > 0:
            a.set_light(x, y, z, SKY_LIGHT, 0)
            removal.push(node(x, y, z, old, SKY_LIGHT))
    if height > old_height:
        # The column is covered higher up: everything from the old height
        # map value to the new one loses its full sky light.
        for cy in range(old_height, min(height, top + 1)):
            if cy == y:
                continue
            var old = a.light(x, cy, z, SKY_LIGHT)
            if old > 0:
                a.set_light(x, cy, z, SKY_LIGHT, 0)
                removal.push(node(x, cy, z, old, SKY_LIGHT))
        if height <= top:
            # The block at the new height map value no longer lights its
            # neighbours in the same chunk.
            _unspread_from_height(a, removal, x, height, z)
    var sources = List[LightNode]()
    _unspread(a, removal, add, sources, SKY_LIGHT)
    if height < old_height:
        # The column opened up: full sky light down to the new height map
        # value, and the block at the old one now spreads it sideways.
        for cy in range(height, min(old_height, top) + 1):
            a.set_light(x, cy, z, SKY_LIGHT, 15)
            add.push(node(x, cy, z, 15, SKY_LIGHT))
    elif y >= height:
        a.set_light(x, y, z, SKY_LIGHT, 15)
        add.push(node(x, y, z, 15, SKY_LIGHT))
    _queue_neighbours(a, add, x, y, z, SKY_LIGHT)
    _respread(a, add)


def _unspread_from_height[
    R: BlockRegistry
](mut a: LightArea[R], mut removal: LightQueue, x: Int, y: Int, z: Int):
    # Removes what the neighbours in the same chunk took from a block that
    # is now at its column's height map value.
    comptime for i in range(6):
        comptime if _dy(i) == 0:
            var nx = x + _dx(i)
            var nz = z + _dz(i)
            if (nx >> 4) == (x >> 4) and (nz >> 4) == (z >> 4):
                var ln = a.light(nx, y, nz, SKY_LIGHT)
                if ln > 0 and ln < 15:
                    a.set_light(nx, y, nz, SKY_LIGHT, 0)
                    removal.push(node(nx, y, nz, ln, SKY_LIGHT))


def _unspread[
    R: BlockRegistry
](
    mut a: LightArea[R],
    mut removal: LightQueue,
    mut add: LightQueue,
    mut sources: List[LightNode],
    lt: UInt8,
):
    # Clears every level that may have come from a removed one: neighbours
    # with less light than it. Neighbours with as much or more light keep it
    # and are queued to spread again into what was cleared; cleared blocks
    # that emit light are added to sources.
    while not removal.empty():
        var n = removal.pop()
        var x = Int(n.x)
        var y = Int(n.y)
        var z = Int(n.z)
        comptime for i in range(6):
            var nx = x + _dx(i)
            var ny = y + _dy(i)
            var nz = z + _dz(i)
            if a.contains(nx, ny, nz):
                var ln = a.light(nx, ny, nz, lt)
                if ln != 0:
                    if ln < n.level:
                        a.set_light(nx, ny, nz, lt, 0)
                        removal.push(node(nx, ny, nz, ln, lt))
                        if lt == BLOCK_LIGHT:
                            var level = a.highest[True](nx, ny, nz)
                            if level > 0:
                                sources.append(node(nx, ny, nz, level, lt))
                    else:
                        add.push(node(nx, ny, nz, ln, lt))


def _queue_neighbours[
    R: BlockRegistry
](mut a: LightArea[R], mut add: LightQueue, x: Int, y: Int, z: Int, lt: UInt8):
    comptime for i in range(6):
        var nx = x + _dx(i)
        var ny = y + _dy(i)
        var nz = z + _dz(i)
        if a.contains(nx, ny, nz):
            var ln = a.light(nx, ny, nz, lt)
            if ln > 0:
                add.push(node(nx, ny, nz, ln, lt))


def _respread[R: BlockRegistry](mut a: LightArea[R], mut add: LightQueue):
    # Spreads light from the queued nodes. A node's level is set when it is
    # queued; a node whose level has changed since (cleared, or raised and
    # queued again) is skipped.
    while not add.empty():
        var n = add.pop()
        var x = Int(n.x)
        var y = Int(n.y)
        var z = Int(n.z)
        if a.light(x, y, z, n.lt) != n.level or n.level <= 1:
            continue
        var at_height = n.lt == SKY_LIGHT and y == a.height(x, z)
        comptime for i in range(6):
            var nx = x + _dx(i)
            var ny = y + _dy(i)
            var nz = z + _dz(i)
            var skip = False
            comptime if _dy(i) == 0:
                # Fill never spreads the block at a column's height map
                # value to the same chunk.
                skip = (
                    at_height
                    and (nx >> 4) == (x >> 4)
                    and (nz >> 4) == (z >> 4)
                )
            if not skip and a.contains(nx, ny, nz):
                var filter = a.highest[False](nx, ny, nz) + 1
                if n.level > filter:
                    var level = n.level - filter
                    if a.light(nx, ny, nz, n.lt) < level:
                        a.set_light(nx, ny, nz, n.lt, level)
                        add.push(node(nx, ny, nz, level, n.lt))
