"""`Hopper`, ported from Dragonfly `server/block/model/hopper.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face, horizontal_faces
from ..cube.pos import Pos
from .solid import FULL


@fieldwise_init
struct Hopper(BlockModel, ImplicitlyCopyable):
    """The model of a hopper (Go `model.Hopper`)."""

    comptime MODEL_ID: Int = 24
    """The model ID of `Hopper`."""

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
        var boxes: List[BBox] = [FULL.extend_towards(Face.UP, -0.375)]
        for f in horizontal_faces():
            boxes.append(FULL.extend_towards(f, -0.875))
        return boxes^

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
        return face == Face.UP
