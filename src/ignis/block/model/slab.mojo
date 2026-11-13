"""`Slab`, ported from Dragonfly `server/block/model/slab.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos
from .solid import FULL


struct Slab(BlockModel, ImplicitlyCopyable):
    """The model of a slab (Go `model.Slab`)."""

    comptime MODEL_ID: Int = 34
    """The model ID of `Slab`."""

    var double: Bool
    """Whether the slab is a double slab."""
    var top: Bool
    """Whether the slab is in the top half."""

    def __init__(out self, *, double: Bool = False, top: Bool = False):
        """Creates the model; omitted fields take Go zero values.

        Args:
            double: Whether the slab is a double slab.
            top: Whether the slab is in the top half.
        """
        self.double = double
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
        if self.double:
            return [FULL]
        if self.top:
            return [BBox.box(0, 0.5, 0, 1, 1, 1)]
        return [BBox.box(0, 0, 0, 1, 0.5, 1)]

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
        if self.double:
            return True
        if self.top:
            return face == Face.UP
        return face == Face.DOWN
