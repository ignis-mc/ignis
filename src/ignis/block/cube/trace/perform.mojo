"""`Perform`, ported from Dragonfly `server/block/cube/trace/result.go`.

Go's `EntityFilter` maps a sequence of entities to the ones that may be hit;
here it is a trait whose `keep` is asked about each entity in range.
"""

from minecraft.protocol.uuid import UUID

from ....mgl64 import Vec3
from ....world.world import World, WorldTypes
from ..bbox import BBox
from ..face import Face
from ..pos import Pos
from .bbox import bbox_intercept
from .block import BlockResult
from .entity import EntityResult, entity_intercept
from .trace import traverse_blocks


trait EntityFilter:
    """Chooses the entities a trace may hit (Go `EntityFilter`)."""

    def keep[T: WorldTypes](self, id: UUID, mut tx: World[T]) -> Bool:
        """Reports whether the entity may be hit."""
        ...


@fieldwise_init
struct AllEntities(EntityFilter, ImplicitlyCopyable):
    """A filter that keeps every entity (Go's nil filter)."""

    def keep[T: WorldTypes](self, id: UUID, mut tx: World[T]) -> Bool:
        """Keeps the entity."""
        return True


@fieldwise_init
struct TraceResult(ImplicitlyCopyable):
    """What `perform` hit: a block or an entity (Go `trace.Result`)."""

    var block: Optional[BlockResult]
    """The block that was hit (Go `BlockResult`)."""
    var entity: Optional[EntityResult]
    """The entity that was hit (Go `EntityResult`)."""

    def position(self) -> Vec3:
        """Returns the point that was hit (Go `Position`)."""
        if case .Some(e) = self.entity:
            return e.position()
        return self.block.value().position()

    def face(self) -> Face:
        """Returns the face that was hit (Go `Face`)."""
        if case .Some(e) = self.entity:
            return e.face()
        return self.block.value().face()

    def bbox(self) -> BBox:
        """Returns the box that was hit (Go `BBox`)."""
        if case .Some(e) = self.entity:
            return e.bbox()
        return self.block.value().bbox()


def trace_block[
    T: WorldTypes
](mut tx: World[T], pos: Pos, start: Vec3, end: Vec3) -> Optional[BlockResult]:
    """Finds where a segment first hits the model of the block at `pos` (Go
    `BlockIntercept` with the world's block)."""
    var br = tx.block_registry()
    var rid = tx.block(pos)
    var bbs = T.Blocks.model_bbox(
        br[].kind(rid), br[].state_hash(rid), pos, tx.source()
    )
    var hit: Optional[BlockResult] = None
    var dist = Float64.MAX
    for bb in bbs:
        if case .Some(next) = bbox_intercept(
            bb.translate(pos.vec3()), start, end
        ):
            var d = next.position().sub(start).len_sqr()
            if d < dist:
                hit = BlockResult(
                    next.bbox(), next.position(), next.face(), pos
                )
                dist = d
    return hit


def perform[
    T: WorldTypes, F: EntityFilter
](
    start: Vec3, end_in: Vec3, mut tx: World[T], box: BBox, filter: F
) -> Optional[TraceResult]:
    """Traces a box along a segment through blocks, then entities, and
    returns the first block or the nearest entity hit (Go `Perform`)."""
    var end = end_in
    var block_hit: Optional[BlockResult] = None
    var positions = List[Pos]()

    def collect(pos: Pos) {mut positions} -> Bool:
        positions.append(pos)
        return True

    traverse_blocks(start, end, collect)
    for pos in positions:
        if case .Some(r) = trace_block(tx, pos, start, end):
            block_hit = r
            end = r.position()
            break

    var dist = Float64.MAX
    var entity_hit: Optional[EntityResult] = None
    var bb = box.translate(start).extend(end.sub(start))
    for id in tx.entities_within(bb.grow(8.0)):
        if not filter.keep(id, tx):
            continue
        var e = tx.entity(id)
        if not e:
            continue
        ref h = e.value()
        var ebox = h.bbox()
        if not ebox.translate(h.data.pos).intersects_with(bb):
            continue
        if case .Some(r) = entity_intercept(id, ebox, h.data.pos, start, end):
            var d = start.sub(r.position()).len_sqr()
            if d < dist:
                dist = d
                entity_hit = r
    if entity_hit:
        return TraceResult(None, entity_hit)
    if block_hit:
        return TraceResult(block_hit, None)
    return None
