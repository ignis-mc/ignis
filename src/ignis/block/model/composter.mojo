"""`Composter`, ported from Dragonfly `server/block/model/composter.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


struct Composter(BlockModel, ImplicitlyCopyable):
    """The model of a composter (Go `model.Composter`)."""

    comptime MODEL_ID: Int = 15
    """The model ID of `Composter`."""

    var level: Int
    """How full the composter is, 0 to 8."""

    def __init__(out self, *, level: Int = 0):
        """Creates the model; omitted fields take Go zero values."""
        self.level = level

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        var compost_height = abs(min(Float64(self.level), 7) * 0.125 - 0.0625)
        return [
            BBox.box(0, 0, 0, 1, 1, 0.125),
            BBox.box(0, 0, 0.875, 1, 1, 1),
            BBox.box(0.875, 0, 0, 1, 1, 1),
            BBox.box(0, 0, 0, 0.125, 1, 1),
            BBox.box(0.125, 0, 0.125, 0.875, 0.125 + compost_height, 0.875),
        ]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return face != Face.UP
