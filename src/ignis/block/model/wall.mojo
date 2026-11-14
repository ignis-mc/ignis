"""`Wall`, ported from Dragonfly `server/block/model/wall.go`.
"""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.axis import Axis
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


struct Wall(BlockModel, ImplicitlyCopyable):
    """The model of a wall (Go `model.Wall`)."""

    comptime MODEL_ID: Int = 40
    """The model ID of `Wall`."""

    var north_connection: Float64
    """The height of the connection to the north; 0 for none."""
    var east_connection: Float64
    """The height of the connection to the east; 0 for none."""
    var south_connection: Float64
    """The height of the connection to the south; 0 for none."""
    var west_connection: Float64
    """The height of the connection to the west; 0 for none."""
    var post: Bool
    """Whether the post is extended to the full height of the block."""

    def __init__(
        out self,
        *,
        north_connection: Float64 = 0,
        east_connection: Float64 = 0,
        south_connection: Float64 = 0,
        west_connection: Float64 = 0,
        post: Bool = False,
    ):
        """Creates the model; omitted fields take Go zero values.

        Args:
            north_connection: The height of the connection to the north; 0 for none.
            east_connection: The height of the connection to the east; 0 for none.
            south_connection: The height of the connection to the south; 0 for none.
            west_connection: The height of the connection to the west; 0 for none.
            post: Whether the post is extended to the full height of the block.
        """
        self.north_connection = north_connection
        self.east_connection = east_connection
        self.south_connection = south_connection
        self.west_connection = west_connection
        self.post = post

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
        var post_height = 1.0 if self.post else 0.8125
        var boxes: List[BBox] = [
            BBox.box(0.25, 0, 0.25, 0.75, post_height, 0.75)
        ]
        if self.north_connection > 0:
            boxes.append(
                BBox.box(0.25, 0, 0, 0.75, self.north_connection, 0.25)
            )
        if self.east_connection > 0:
            boxes.append(BBox.box(0.75, 0, 0.25, 1, self.east_connection, 0.75))
        if self.south_connection > 0:
            boxes.append(
                BBox.box(0.25, 0, 0.75, 0.75, self.south_connection, 1)
            )
        if self.west_connection > 0:
            boxes.append(BBox.box(0, 0, 0.25, 0.25, self.west_connection, 0.75))
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
        return face.axis() == Axis.Y
