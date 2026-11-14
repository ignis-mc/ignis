"""`EndRod`, ported from Dragonfly `server/block/model/end_rod.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.axis import Axis
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


struct EndRod(BlockModel, ImplicitlyCopyable):
    """The model of an end rod (Go `model.EndRod`)."""

    comptime MODEL_ID: Int = 20
    """The model ID of `EndRod`."""

    var axis: Axis
    """The axis the end rod faces."""

    def __init__(out self, *, axis: Axis = Axis.Y):
        """Creates the model; omitted fields take Go zero values."""
        self.axis = axis

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return [
            BBox.box(0.375, 0.375, 0.375, 0.625, 0.625, 0.625).stretch(
                self.axis, 0.375
            )
        ]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
