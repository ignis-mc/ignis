"""`BrewingStand`, ported from Dragonfly `server/block/model/brewing_stand.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.axis import Axis
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos
from .solid import FULL


@fieldwise_init
struct BrewingStand(BlockModel, ImplicitlyCopyable):
    """The model of a brewing stand (Go `model.BrewingStand`)."""

    comptime MODEL_ID: Int = 6
    """The model ID of `BrewingStand`."""

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return [
            FULL.extend_towards(Face.UP, -0.875),
            FULL.stretch(Axis.X, -0.4375)
            .stretch(Axis.Z, -0.4375)
            .extend_towards(Face.DOWN, 0.125),
        ]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
