"""`Candle`, ported from Dragonfly `server/block/model/candle.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


struct Candle(BlockModel, ImplicitlyCopyable):
    """The model of a candle block (Go `model.Candle`)."""

    comptime MODEL_ID: Int = 10
    """The model ID of `Candle`."""

    var count: Int
    """The number of candles, 1 to 4."""

    def __init__(out self, *, count: Int = 0):
        """Creates the model; omitted fields take Go zero values."""
        self.count = count

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        if self.count == 2:
            return [BBox.box(0.3125, 0, 0.4375, 0.6875, 0.375, 0.625)]
        if self.count == 3:
            return [BBox.box(0.3125, 0, 0.375, 0.625, 0.375, 0.6875)]
        if self.count == 4:
            return [BBox.box(0.3125, 0, 0.3125, 0.6875, 0.375, 0.625)]
        return [BBox.box(0.4375, 0, 0.4375, 0.5625, 0.375, 0.5625)]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
