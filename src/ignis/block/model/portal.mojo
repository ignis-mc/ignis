"""`Portal`, ported from Dragonfly `server/block/model/portal.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.axis import Axis
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


struct Portal(BlockModel, ImplicitlyCopyable):
    """The model of a nether portal block, without collision (Go `model.Portal`).
    """

    comptime MODEL_ID: Int = 30
    """The model ID of `Portal`."""

    var axis: Axis
    """The axis the portal faces."""

    def __init__(out self, *, axis: Axis = Axis.Y):
        """Creates the model; omitted fields take Go zero values."""
        self.axis = axis

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return []

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
