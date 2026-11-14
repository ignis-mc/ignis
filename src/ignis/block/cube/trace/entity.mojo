"""Ray intersections with entities, ported from Dragonfly
`server/block/cube/trace/entity.go`.

Go holds the entity in the result; here the result holds its UUID.
"""

from minecraft.protocol.uuid import UUID

from ....mgl64 import Vec3
from ..bbox import BBox
from ..face import Face
from .bbox import bbox_intercept
from .result import Result


@fieldwise_init
struct EntityResult(ImplicitlyCopyable, Result):
    """The result of a ray hitting an entity (Go `trace.EntityResult`)."""

    var _bb: BBox
    var _pos: Vec3
    var _face: Face
    var _entity: UUID

    def bbox(self) -> BBox:
        """Returns the grown box of the entity that was hit (Go `BBox`)."""
        return self._bb

    def position(self) -> Vec3:
        """Returns the point where the ray hit (Go `Position`)."""
        return self._pos

    def face(self) -> Face:
        """Returns the face that was hit (Go `Face`)."""
        return self._face

    def entity(self) -> UUID:
        """Returns the entity that was hit (Go `Entity`)."""
        return self._entity


def entity_intercept(
    id: UUID, box: BBox, pos: Vec3, start: Vec3, end: Vec3
) -> Optional[EntityResult]:
    """Finds where a segment hits an entity with box `box` at `pos`, grown
    by 0.3 (Go `EntityIntercept`)."""
    var bb = box.translate(pos).grow(0.3)
    if case .Some(r) = bbox_intercept(bb, start, end):
        return EntityResult(bb, r.position(), r.face(), id)
    return None
