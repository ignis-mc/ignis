"""`Solid` and the full block box, ported from Dragonfly `server/block/model/solid.go`.
"""

from ...mgl64 import Vec3
from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


@fieldwise_init
struct Solid(BlockModel, ImplicitlyCopyable):
    """The model of a block that fills its whole space (Go `model.Solid`)."""

    comptime MODEL_ID: Int = 1
    """The model ID of `Solid`."""

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return [FULL]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return True


comptime FULL = BBox(Vec3(0, 0, 0), Vec3(1, 1, 1))
"""The box of a full block (Go `full`)."""
