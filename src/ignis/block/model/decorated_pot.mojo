"""`DecoratedPot`, ported from Dragonfly `server/block/model/decorated_pot.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.axis import Axis
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


@fieldwise_init
struct DecoratedPot(BlockModel, ImplicitlyCopyable):
    """The model of a decorated pot (Go `model.DecoratedPot`)."""

    comptime MODEL_ID: Int = 16
    """The model ID of `DecoratedPot`."""

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return [BBox.box(0.025, 0, 0.025, 0.975, 1, 0.975)]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return face.axis() == Axis.Y
