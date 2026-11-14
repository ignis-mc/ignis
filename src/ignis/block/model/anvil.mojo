"""`Anvil`, ported from Dragonfly `server/block/model/anvil.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.direction import Direction
from ..cube.face import Face
from ..cube.pos import Pos
from .solid import FULL


struct Anvil(BlockModel, ImplicitlyCopyable):
    """The model of an anvil (Go `model.Anvil`)."""

    comptime MODEL_ID: Int = 3
    """The model ID of `Anvil`."""

    var facing: Direction
    """The direction the anvil faces."""

    def __init__(out self, *, facing: Direction = Direction.NORTH):
        """Creates the model; omitted fields take Go zero values.

        Args:
            facing: The direction the anvil faces.
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
        return [FULL.stretch(self.facing.rotate_left().face().axis(), -0.125)]

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
