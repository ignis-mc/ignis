"""`Leaves`, ported from Dragonfly `server/block/model/leaves.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos
from .solid import FULL


@fieldwise_init
struct Leaves(BlockModel, ImplicitlyCopyable):
    """The model of leaves: a full box whose faces are not solid (Go `model.Leaves`).
    """

    comptime MODEL_ID: Int = 27
    """The model ID of `Leaves`."""

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return [FULL]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
