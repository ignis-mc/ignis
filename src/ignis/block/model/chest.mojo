"""`Chest`, ported from Dragonfly `server/block/model/chest.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


@fieldwise_init
struct Chest(BlockModel, ImplicitlyCopyable):
    """The model of a chest (Go `model.Chest`)."""

    comptime MODEL_ID: Int = 13
    """The model ID of `Chest`."""

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return [BBox.box(0.025, 0, 0.025, 0.975, 0.95, 0.975)]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
