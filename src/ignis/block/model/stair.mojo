"""`Stair`, ported from Dragonfly `server/block/model/stair.go`.
"""

from ...mgl64 import Vec3
from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.direction import Direction
from ..cube.face import Face
from ..cube.pos import Pos


struct Stair(BlockModel, ImplicitlyCopyable):
    """The model of stairs (Go `model.Stair`)."""

    comptime MODEL_ID: Int = 35
    """The model ID of `Stair`."""

    var facing: Direction
    """The direction the full side faces."""
    var upside_down: Bool
    """Whether the stairs are upside down."""
    var corner: Bool
    """Whether the stairs form a corner."""
    var inner: Bool
    """Whether the corner is an inner corner."""
    var left: Bool
    """Whether the corner turns left."""

    def __init__(
        out self,
        *,
        facing: Direction = Direction.NORTH,
        upside_down: Bool = False,
        corner: Bool = False,
        inner: Bool = False,
        left: Bool = False,
    ):
        """Creates the model; omitted fields take Go zero values.

        Args:
            facing: The direction the full side faces.
            upside_down: Whether the stairs are upside down.
            corner: Whether the stairs form a corner.
            inner: Whether the corner is an inner corner.
            left: Whether the corner turns left.
        """
        self.facing = facing
        self.upside_down = upside_down
        self.corner = corner
        self.inner = inner
        self.left = left

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
        var b: List[BBox] = [BBox.box(0, 0, 0, 1, 0.5, 1)]
        if self.upside_down:
            b[0] = BBox.box(0, 0.5, 0, 1, 1, 1)
        var step = BBox.box(0.5, 0.5, 0.5, 0.5, 1, 0.5)
        if not self.corner or self.inner:
            b.append(
                step.extend_towards(self.facing.face(), 0.5).stretch(
                    self.facing.rotate_right().face().axis(), 0.5
                )
            )
        if self.corner:
            var face = self.facing.face()
            if self.inner:
                face = self.facing.opposite().face()
            b.append(
                step.extend_towards(face, 0.5).extend_towards(
                    self._corner_face(), 0.5
                )
            )
        if self.upside_down:
            for i in range(1, len(b)):
                b[i] = b[i].translate(Vec3(0, -0.5, 0))
        return b^

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
        if (face == Face.UP and self.upside_down) or (
            face == Face.DOWN and not self.upside_down
        ):
            return True
        if not self.corner:
            return face == self.facing.face()
        if not self.inner:
            return False
        return face == self._corner_face() or face == self.facing.face()

    def _corner_face(self) -> Face:
        if self.left:
            return self.facing.rotate_left().face()
        return self.facing.rotate_right().face()
