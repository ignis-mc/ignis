"""`TilledGrass`, ported from Dragonfly `server/block/model/tilled_grass.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos
from .solid import FULL


@fieldwise_init
struct TilledGrass(BlockModel, ImplicitlyCopyable):
    """The model of farmland and dirt paths (Go `model.TilledGrass`)."""

    comptime MODEL_ID: Int = 38
    """The model ID of `TilledGrass`."""

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return [FULL.extend_towards(Face.UP, -0.0625)]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return True
