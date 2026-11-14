"""`ShelfMushroom`, ported from Dragonfly `server/block/model/shelf_mushroom.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.direction import Direction
from ..cube.face import Face
from ..cube.pos import Pos
from .solid import FULL


struct ShelfMushroom(BlockModel, ImplicitlyCopyable):
    """The model of a shelf mushroom (Go `model.ShelfMushroom`)."""

    comptime MODEL_ID: Int = 31
    """The model ID of `ShelfMushroom`."""

    var facing: Direction
    """The direction the mushroom faces."""
    var large: Bool
    """Whether the mushroom is large."""

    def __init__(
        out self, *, facing: Direction = Direction.NORTH, large: Bool = False
    ):
        """Creates the model; omitted fields take Go zero values."""
        self.facing = facing
        self.large = large

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        var depth = 0.75 if self.large else 0.5
        return [
            FULL.extend_towards(Face.UP, -0.75).extend_towards(
                self.facing.face(), -(1 - depth)
            )
        ]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
