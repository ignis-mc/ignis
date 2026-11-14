"""`Door`, ported from Dragonfly `server/block/model/door.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.direction import Direction
from ..cube.face import Face
from ..cube.pos import Pos
from .solid import FULL


struct Door(BlockModel, ImplicitlyCopyable):
    """The model of a door (Go `model.Door`)."""

    comptime MODEL_ID: Int = 17
    """The model ID of `Door`."""

    var facing: Direction
    """The direction the door faces."""
    var open: Bool
    """Whether the door is open."""
    var right: Bool
    """Whether the hinge is on the right side."""

    def __init__(
        out self,
        *,
        facing: Direction = Direction.NORTH,
        open: Bool = False,
        right: Bool = False,
    ):
        """Creates the model; omitted fields take Go zero values."""
        self.facing = facing
        self.open = open
        self.right = right

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        if self.open:
            if self.right:
                return [
                    FULL.extend_towards(
                        self.facing.rotate_left().face(), -0.8125
                    )
                ]
            return [
                FULL.extend_towards(self.facing.rotate_right().face(), -0.8125)
            ]
        return [FULL.extend_towards(self.facing.face(), -0.8125)]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
