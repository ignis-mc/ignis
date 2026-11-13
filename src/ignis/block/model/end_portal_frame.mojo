"""`EndPortalFrame`, ported from Dragonfly `server/block/model/end_portal_frame.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


@fieldwise_init
struct EndPortalFrame(BlockModel, ImplicitlyCopyable):
    """The model of an end portal frame (Go `model.EndPortalFrame`)."""

    comptime MODEL_ID: Int = 19
    """The model ID of `EndPortalFrame`."""

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
        return [BBox.box(0, 0, 0, 1, 0.8125, 1)]

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
        return face == Face.DOWN
