"""`Trapdoor`, ported from Dragonfly `server/block/model/trapdoor.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.direction import Direction
from ..cube.face import Face
from ..cube.pos import Pos
from .solid import FULL


struct Trapdoor(BlockModel, ImplicitlyCopyable):
    """The model of a trapdoor (Go `model.Trapdoor`)."""

    comptime MODEL_ID: Int = 39
    """The model ID of `Trapdoor`."""

    var facing: Direction
    """The direction the trapdoor faces."""
    var open: Bool
    """Whether the trapdoor is open."""
    var top: Bool
    """Whether the trapdoor is in the top half."""

    def __init__(
        out self,
        *,
        facing: Direction = Direction.NORTH,
        open: Bool = False,
        top: Bool = False,
    ):
        """Creates the model; omitted fields take Go zero values.

        Args:
            facing: The direction the trapdoor faces.
            open: Whether the trapdoor is open.
            top: Whether the trapdoor is in the top half.
        """
        self.facing = facing
        self.open = open
        self.top = top

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
        if self.open:
            return [FULL.extend_towards(self.facing.face(), -0.8125)]
        if self.top:
            return [BBox.box(0, 0.8125, 0, 1, 1, 1)]
        return [BBox.box(0, 0, 0, 1, 0.1875, 1)]

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
        if self.open:
            return self.facing.face().opposite() == face
        if self.top:
            return face == Face.UP
        return face == Face.DOWN
