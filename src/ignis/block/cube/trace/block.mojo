"""Ray intersections with blocks, ported from Dragonfly
`server/block/cube/trace/block.go`.

Go passes the block as a `world.Block`; here it is an `AnyBlock`, whose
model is found through `ignis.block.register`.
"""

from ....mgl64 import Vec3
from ....world.block_source import BlockSource
from ...hash import AnyBlock
from ...register import block_model_bbox
from ..bbox import BBox
from ..face import Face
from ..pos import Pos
from .bbox import BBoxResult, bbox_intercept, bbox_intersects
from .result import Result


@fieldwise_init
struct BlockResult(ImplicitlyCopyable, Result):
    """The result of a ray hitting a block (Go `trace.BlockResult`)."""

    var _bb: BBox
    var _pos: Vec3
    var _face: Face
    var _block_pos: Pos

    def bbox(self) -> BBox:
        """Returns the box of the block that was hit (Go `BBox`).

        Returns:
            The box, in world coordinates.
        """
        return self._bb

    def position(self) -> Vec3:
        """Returns the point where the ray hit the block (Go `Position`).

        Returns:
            The point.
        """
        return self._pos

    def face(self) -> Face:
        """Returns the face of the block that was hit (Go `Face`).

        Returns:
            The face.
        """
        return self._face

    def block_position(self) -> Pos:
        """Returns the position of the block that was hit (Go
        `BlockPosition`).

        Returns:
            The position.
        """
        return self._block_pos


def block_intercept[
    S: BlockSource
](pos: Pos, src: S, b: AnyBlock, start: Vec3, end: Vec3) -> Optional[
    BlockResult
]:
    """Finds where the segment from `start` to `end` first hits the model of
    a block (Go `BlockIntercept`).

    Parameters:
        S: The block source type.

    Args:
        pos: The position of the block.
        src: The blocks around it.
        b: The block.
        start: The start of the ray.
        end: The end of the ray.

    Returns:
        The hit on the nearest box, or None if the ray misses the block.
    """
    var bbs = block_model_bbox(b, pos, src)
    var hit = Optional[BBoxResult](None)
    var dist = Float64.MAX
    for bb in bbs:
        if case .Some(next) = bbox_intercept(
            bb.translate(pos.vec3()), start, end
        ):
            var next_dist = next.position().sub(start).len_sqr()
            if next_dist < dist:
                hit = next
                dist = next_dist
    if case .Some(h) = hit:
        return BlockResult(h.bbox(), h.position(), h.face(), pos)
    return None


def block_intersects[
    S: BlockSource
](pos: Pos, src: S, b: AnyBlock, start: Vec3, end: Vec3) -> Bool:
    """Reports whether the segment from `start` to `end` touches the model of
    a block (Go `BlockIntersects`). Go short-cuts `model.Empty` (no boxes)
    and `model.Solid` (one full box); both give the same result through
    their boxes.

    Parameters:
        S: The block source type.

    Args:
        pos: The position of the block.
        src: The blocks around it.
        b: The block.
        start: The start of the ray.
        end: The end of the ray.

    Returns:
        True if the ray touches one of the block's boxes.
    """
    for bb in block_model_bbox(b, pos, src):
        if bbox_intersects(bb.translate(pos.vec3()), start, end):
            return True
    return False
