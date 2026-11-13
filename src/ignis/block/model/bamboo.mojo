"""`Bamboo`, ported from Dragonfly `server/block/model/bamboo.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos
from .offset import random_offset


struct Bamboo(BlockModel, ImplicitlyCopyable):
    """The model of bamboo, offset randomly by its position (Go `model.Bamboo`).
    """

    comptime MODEL_ID: Int = 4
    """The model ID of `Bamboo`."""

    var thick: Bool
    """Whether the stalk is thick."""

    def __init__(out self, *, thick: Bool = False):
        """Creates the model; omitted fields take Go zero values.

        Args:
            thick: Whether the stalk is thick.
        """
        self.thick = thick

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
        var size = 0.5 + 2.0 / 16.0
        if self.thick:
            size = 0.5 + 3.0 / 16.0
        var offset = random_offset(pos, -0.25, 0.25, 16)
        return [BBox.box(0.5, 0, 0.5, size, 1, size).translate(offset)]

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
