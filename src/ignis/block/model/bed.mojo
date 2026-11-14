"""`Bed`, ported from Dragonfly `server/block/model/bed.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


@fieldwise_init
struct Bed(BlockModel, ImplicitlyCopyable):
    """The model of a bed (Go `model.Bed`)."""

    comptime MODEL_ID: Int = 5
    """The model ID of `Bed`."""

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return [BBox.box(0, 0, 0, 1, 0.5625, 1)]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
