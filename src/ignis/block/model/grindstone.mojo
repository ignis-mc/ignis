"""`Grindstone`, ported from Dragonfly `server/block/model/grindstone.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.axis import Axis
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


struct Grindstone(BlockModel, ImplicitlyCopyable):
    """The model of a grindstone (Go `model.Grindstone`)."""

    comptime MODEL_ID: Int = 23
    """The model ID of `Grindstone`."""

    var axis: Axis
    """The axis the grindstone's wheel turns around."""

    def __init__(out self, *, axis: Axis = Axis.Y):
        """Creates the model; omitted fields take Go zero values."""
        self.axis = axis

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return [
            BBox.box(0.125, 0.125, 0.125, 0.825, 0.825, 0.825).stretch(
                self.axis, 0.125
            )
        ]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
