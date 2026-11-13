"""`Cake`, ported from Dragonfly `server/block/model/cake.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


struct Cake(BlockModel, ImplicitlyCopyable):
    """The model of a cake (Go `model.Cake`)."""

    comptime MODEL_ID: Int = 8
    """The model ID of `Cake`."""

    var bites: Int
    """The number of bites taken out of the cake."""

    def __init__(out self, *, bites: Int = 0):
        """Creates the model; omitted fields take Go zero values.

        Args:
            bites: The number of bites taken out of the cake.
        """
        self.bites = bites

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
        return [
            BBox.box(0.0625, 0, 0.0625, 0.9375, 0.5, 0.9375).extend_towards(
                Face.WEST, -(Float64(self.bites) / 8)
            )
        ]

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
