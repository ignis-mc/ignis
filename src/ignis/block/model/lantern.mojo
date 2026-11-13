"""`Lantern`, ported from Dragonfly `server/block/model/lantern.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


struct Lantern(BlockModel, ImplicitlyCopyable):
    """The model of a lantern (Go `model.Lantern`)."""

    comptime MODEL_ID: Int = 26
    """The model ID of `Lantern`."""

    var hanging: Bool
    """Whether the lantern hangs from a block."""

    def __init__(out self, *, hanging: Bool = False):
        """Creates the model; omitted fields take Go zero values.

        Args:
            hanging: Whether the lantern hangs from a block.
        """
        self.hanging = hanging

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
        if self.hanging:
            return [BBox.box(0.3125, 0.125, 0.3125, 0.6875, 0.625, 0.6875)]
        return [BBox.box(0.3125, 0, 0.3125, 0.6875, 0.5, 0.6875)]

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
