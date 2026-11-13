"""`Ladder`, ported from Dragonfly `server/block/model/ladder.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.direction import Direction
from ..cube.face import Face
from ..cube.pos import Pos
from .solid import FULL


struct Ladder(BlockModel, ImplicitlyCopyable):
    """The model of a ladder (Go `model.Ladder`)."""

    comptime MODEL_ID: Int = 25
    """The model ID of `Ladder`."""

    var facing: Direction
    """The direction the ladder faces."""

    def __init__(out self, *, facing: Direction = Direction.NORTH):
        """Creates the model; omitted fields take Go zero values.

        Args:
            facing: The direction the ladder faces.
        """
        self.facing = facing

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`).

        Parameters:
            S: The block source type.

        Args:
            pos: The position of the block.
            src: The blocks around it.

        Returns:
            The boxes, relative to the block.
        """
        return [FULL.extend_towards(self.facing.face(), -0.8125)]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`).

        Parameters:
            S: The block source type.

        Args:
            pos: The position of the block.
            face: The face.
            src: The blocks around it.

        Returns:
            True if the face is solid.
        """
        return False
