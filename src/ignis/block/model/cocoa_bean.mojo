"""`CocoaBean`, ported from Dragonfly `server/block/model/cocoa_bean.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.direction import Direction
from ..cube.face import Face
from ..cube.pos import Pos
from .solid import FULL


struct CocoaBean(BlockModel, ImplicitlyCopyable):
    """The model of a cocoa bean (Go `model.CocoaBean`)."""

    comptime MODEL_ID: Int = 14
    """The model ID of `CocoaBean`."""

    var facing: Direction
    """The direction from the cocoa bean to the log."""
    var age: Int
    """The stage of growth, 0 to 2."""

    def __init__(
        out self, *, facing: Direction = Direction.NORTH, age: Int = 0
    ):
        """Creates the model; omitted fields take Go zero values.

        Args:
            facing: The direction from the cocoa bean to the log.
            age: The stage of growth, 0 to 2.
        """
        self.facing = facing
        self.age = age

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
        var age = Float64(self.age)
        return [
            FULL.stretch(
                self.facing.rotate_right().face().axis(), -(6 - age) / 16
            )
            .extend_towards(Face.UP, -0.25)
            .extend_towards(Face.DOWN, -((7 - age * 2) / 16))
            .extend_towards(self.facing.face(), -0.0625)
            .extend_towards(
                self.facing.opposite().face(), -((11 - age * 2) / 16)
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
