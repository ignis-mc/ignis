"""`LilyPad`, ported from Dragonfly `server/block/model/lily_pad.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


@fieldwise_init
struct LilyPad(BlockModel, ImplicitlyCopyable):
    """The model of a lily pad (Go `model.LilyPad`)."""

    comptime MODEL_ID: Int = 29
    """The model ID of `LilyPad`."""

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return [BBox.box(0.0625, 0, 0.0625, 0.9375, 0.015625, 0.9375)]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
