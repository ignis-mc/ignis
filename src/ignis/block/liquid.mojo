"""Liquid flow, ported from Dragonfly `server/block/liquid.go`.

`tick_liquid` is Go's `tickLiquid` for any typed `Liquid`; the blocks it
meets are runtime IDs, whose `Liquid`, `LiquidDisplacer` and
`LiquidRemovable` methods go through the world's block set. Go's pooled
node queue becomes a list per call; nodes keep the index of their parent in
it instead of a pointer.
"""

from ..world.block import Liquid
from ..world.block_set import BlockTypes
from ..world.tx import Context
from ..world.world import World, WorldTypes
from .cube.face import Face
from .cube.pos import Pos
from .hash import AnyBlock
from .water import Water


trait LiquidRemovable:
    """A block a liquid may flow into and remove (Go `LiquidRemovable`)."""

    def has_liquid_drops(self) -> Bool:
        """Reports whether the block drops its items when a liquid removes
        it (Go `HasLiquidDrops`)."""
        ...


def source_water_can_displace(b: AnyBlock) -> Bool:
    """Go `sourceWaterDisplacer.CanDisplace`: water source blocks only."""
    if case .Some(w) = b.get[Water]():
        return not w.falling and w.depth == 8
    return False


def flowing_water_can_displace(b: AnyBlock) -> Bool:
    """Go `flowingWaterDisplacer.CanDisplace`: any water."""
    return b.is_a[Water]()


def liquid_replaceable_by[B: BlockTypes](b: AnyBlock) -> Bool:
    """Go `Water.ReplaceableBy` and `Lava.ReplaceableBy`: anything but a
    block a liquid would remove, unless it holds or is a liquid."""
    if B.liquid_removable(b.kind, b.state):
        return Bool(B.liquid_info(b.kind, b.state)) or B.is_liquid_displacer(
            b.kind
        )
    return True


def tick_liquid[L: Liquid, T: WorldTypes](b_in: L, pos: Pos, mut tx: World[T]):
    """Spreads or decays a liquid, or turns it solid next to another liquid
    (Go `tickLiquid`)."""
    var b = b_in.copy()
    if not _source(b) and not _source_around(b, pos, tx):
        var res: Optional[L] = None
        if b.liquid_depth() - 4 > 0:
            res = b.with_depth(b.liquid_depth() - 2 * b.spread_decay(), False)
        var ctx = Context()
        var after: Optional[AnyBlock] = None
        if case .Some(ref r) = res:
            after = AnyBlock(r)
        tx.handle_liquid_decay(ctx, pos, AnyBlock(b), after)
        if ctx.cancelled():
            return
        if case .Some(ref r) = res:
            tx.set_liquid(pos, r)
        else:
            tx.remove_liquid(pos)
        return
    var displacer = _displacer_at(tx, pos)

    var below = pos.side(Face.DOWN)
    var can_flow_below = can_flow_into(b, tx, below, False)
    if b.liquid_falling() and not can_flow_below:
        b = b.with_depth(8, True)
    elif can_flow_below:
        if not _closed(tx, displacer, pos, below):
            _ = flow_into(b.with_depth(8, True), pos, below, tx, True)

    var depth = b.liquid_depth()
    var decay = b.spread_decay()
    if depth <= decay:
        # Spreading would leave nothing.
        return
    if _source(b) or not can_flow_below:
        var paths = _calculate_liquid_paths(b, pos, tx, displacer)
        if len(paths) == 0:
            _spread_outwards(b, pos, tx, displacer)
            return
        var smallest_len = len(paths[0])
        for ref path in paths:
            if len(path) <= smallest_len:
                _ = flow_into(b, pos, path[0], tx, False)


def _source[L: Liquid](b: L) -> Bool:
    # Go `source`.
    return b.liquid_depth() == 8 and not b.liquid_falling()


def _displacer_at[
    T: WorldTypes
](mut tx: World[T], pos: Pos) -> Optional[AnyBlock]:
    # Go `tx.Block(pos).(world.LiquidDisplacer)`.
    var rid = tx.block(pos)
    var br = tx.block_registry()
    if br[].liquid_displacing_block(rid):
        return AnyBlock(kind=br[].kind(rid), state=br[].state_hash(rid))
    return None


def _closed[
    T: WorldTypes
](mut tx: World[T], displacer: Optional[AnyBlock], pos: Pos, side: Pos) -> Bool:
    # Go `displacer != nil && displacer.SideClosed(pos, side, tx)`.
    if case .Some(d) = displacer:
        return T.Blocks.side_closed(d.kind, d.state, pos, side, tx)
    return False


def _spread_outwards[
    L: Liquid, T: WorldTypes
](b: L, pos: Pos, mut tx: World[T], displacer: Optional[AnyBlock]):
    # Go `spreadOutwards`.
    for neighbour in pos.neighbours(tx.range()):
        if neighbour.y() == pos.y():
            if not _closed(tx, displacer, pos, neighbour):
                _ = flow_into(b, pos, neighbour, tx, False)


def _source_around[
    L: Liquid, T: WorldTypes
](b: L, pos: Pos, mut tx: World[T]) -> Bool:
    # Go `sourceAround`.
    var present = False
    for neighbour in pos.neighbours(tx.range()):
        if neighbour.y() == pos.y() - 1:
            # Liquid below does not feed this one.
            continue
        var side = tx.liquid_info(neighbour)
        if not side or side.value().liquid_type != b.liquid_type():
            continue
        if _closed(tx, _displacer_at(tx, neighbour), neighbour, pos):
            # The side towards this liquid is closed.
            continue
        var s = side.value()
        if (
            neighbour.y() == pos.y() + 1
            or s.source()
            or s.depth > b.liquid_depth()
        ):
            present = True
    return present


def flow_into[
    L: Liquid, T: WorldTypes
](b: L, src: Pos, pos: Pos, mut tx: World[T], falling: Bool) -> Bool:
    """Makes a liquid flow from `src` into `pos`, removing the block there
    (Go `flowInto`); reports whether liquid is there afterwards."""
    var new_depth = b.liquid_depth() - b.spread_decay()
    if falling:
        new_depth = b.liquid_depth()
    if new_depth <= 0 and not falling:
        return False
    var br = tx.block_registry()
    var existing = tx.block(pos)
    var kind = br[].kind(existing)
    var hash = br[].state_hash(existing)
    var res = b.with_depth(new_depth, falling)
    if case .Some(e) = T.Blocks.liquid_info(kind, hash):
        if e.liquid_type == b.liquid_type():
            if e.depth >= new_depth or e.falling:
                # The liquid there is as deep or falling (counted as full).
                return True
            var ctx = Context()
            tx.handle_liquid_flow(
                ctx, src, pos, AnyBlock(res), AnyBlock(kind=kind, state=hash)
            )
            if ctx.cancelled():
                return False
            tx.set_liquid(pos, res)
            return True
        _ = T.Blocks.harden_liquid(kind, hash, pos, tx, Optional(src))
        return False
    var is_displacer = br[].liquid_displacing_block(existing)
    if is_displacer and tx.liquid(pos):
        # The displacer already holds a liquid.
        return False
    var removable = T.Blocks.liquid_removable(kind, hash)
    if not removable and (
        not is_displacer or not T.Blocks.can_displace(kind, hash, AnyBlock(res))
    ):
        return False
    var ctx = Context()
    tx.handle_liquid_flow(
        ctx, src, pos, AnyBlock(res), AnyBlock(kind=kind, state=hash)
    )
    if ctx.cancelled():
        return False
    if removable and existing != br[].air_runtime_id():
        tx.set_block_runtime_id(pos, br[].air_runtime_id())
        b.liquid_remove_block(pos, tx, existing)
    tx.set_liquid(pos, res)
    return True


def can_flow_into[
    L: Liquid, T: WorldTypes
](b: L, mut tx: World[T], pos: Pos, sideways: Bool) -> Bool:
    """Reports whether a liquid can flow into the block at `pos` (Go
    `canFlowInto`)."""
    var br = tx.block_registry()
    var rid = tx.block(pos)
    if rid == br[].air_runtime_id():
        return True
    var kind = br[].kind(rid)
    var hash = br[].state_hash(rid)
    if T.Blocks.liquid_removable(kind, hash):
        if sideways:
            if case .Some(l) = T.Blocks.liquid_info(kind, hash):
                if l.source() or l.liquid_type != b.liquid_type():
                    # A source or another liquid cannot be flowed into.
                    return False
        return True
    if br[].liquid_displacing_block(rid):
        var res = b.with_depth(
            b.liquid_depth() - b.spread_decay(), not sideways
        )
        if T.Blocks.can_displace(kind, hash, AnyBlock(res)):
            return True
    return False


@fieldwise_init
struct _LiquidNode(Copyable, ImplicitlyCopyable):
    # Go `liquidNode`; `previous` is an index into the visited nodes.
    var x: Int
    var z: Int
    var depth: Int8
    var previous: Int
    var length: Int


def _calculate_liquid_paths[
    L: Liquid, T: WorldTypes
](b: L, pos: Pos, mut tx: World[T], displacer: Optional[AnyBlock]) -> List[
    List[Pos]
]:
    # Go `calculateLiquidPaths`. `nodes` holds every node taken from the
    # queue, so children can name their parent by index.
    var queue = List[_LiquidNode]()
    var qi = 0
    var shortest_path = Int(Int8.MAX)
    var nodes = List[_LiquidNode]()
    queue.append(_LiquidNode(pos.x(), pos.z(), Int8(b.liquid_depth()), -1, 0))
    var decay = Int8(b.spread_decay())

    var paths = List[List[Pos]]()
    var first = True
    while len(queue) - qi != 0:
        var node = queue[qi]
        qi += 1
        var idx = len(nodes)
        nodes.append(node)
        var d = node.depth - decay * 2
        var l = node.length + 1
        var neighbours = [
            _LiquidNode(node.x - 1, node.z, d, idx, l),
            _LiquidNode(node.x + 1, node.z, d, idx, l),
            _LiquidNode(node.x, node.z - 1, d, idx, l),
            _LiquidNode(node.x, node.z + 1, d, idx, l),
        ]
        for n in neighbours:
            if not first or not _closed(
                tx, displacer, pos, Pos(n.x, pos.y(), n.z)
            ):
                if _spread_neighbour(b, pos, tx, n, queue, shortest_path):
                    shortest_path = n.length
                    paths.append(_path(n, nodes, pos))
        first = False
    return paths^


def _spread_neighbour[
    L: Liquid, T: WorldTypes
](
    b: L,
    src: Pos,
    mut tx: World[T],
    node: _LiquidNode,
    mut queue: List[_LiquidNode],
    shortest_path: Int,
) -> Bool:
    # Go `spreadNeighbour`: spreads the path search, not the liquid.
    if node.depth + 3 <= 0:
        return False
    if node.length > shortest_path:
        return False
    var pos = Pos(node.x, src.y(), node.z)
    if not can_flow_into(b, tx, pos, True):
        return False
    if can_flow_into(b, tx, Pos(node.x, src.y() - 1, node.z), False):
        return True
    queue.append(node)
    return False


def _path(node: _LiquidNode, nodes: List[_LiquidNode], src: Pos) -> List[Pos]:
    # Go `liquidNode.Path`: the positions from the first step to the node.
    var path = List[Pos](length=node.length, fill=Pos(0, 0, 0))
    var n = node
    var i = node.length - 1
    while n.previous >= 0:
        path[i] = Pos(n.x, src.y(), n.z)
        n = nodes[n.previous]
        i -= 1
    return path^
