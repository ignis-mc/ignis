"""`Chain`, ported from Dragonfly `server/block/model/chain.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.axis import Axis
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


struct Chain(BlockModel, ImplicitlyCopyable):
    """The model of a chain (Go `model.Chain`)."""

    comptime MODEL_ID: Int = 12
    """The model ID of `Chain`."""

    var axis: Axis
    """The axis the chain faces."""

    def __init__(out self, *, axis: Axis = Axis.Y):
        """Creates the model; omitted fields take Go zero values."""
        self.axis = axis

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return [
            BBox.box(
                0.40625, 0.40625, 0.40625, 0.59375, 0.59375, 0.59375
            ).stretch(self.axis, 0.40625)
        ]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
