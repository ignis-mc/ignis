"""`FenceGate`, ported from Dragonfly `server/block/model/fence_gate.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.direction import Direction
from ..cube.face import Face
from ..cube.pos import Pos


struct FenceGate(BlockModel, ImplicitlyCopyable):
    """The model of a fence gate (Go `model.FenceGate`)."""

    comptime MODEL_ID: Int = 22
    """The model ID of `FenceGate`."""

    var facing: Direction
    """The direction the gate faces."""
    var open: Bool
    """Whether the gate is open."""

    def __init__(
        out self, *, facing: Direction = Direction.NORTH, open: Bool = False
    ):
        """Creates the model; omitted fields take Go zero values."""
        self.facing = facing
        self.open = open

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        if self.open:
            return []
        return [
            BBox.box(0, 0, 0, 1, 1.5, 1).stretch(
                self.facing.face().axis(), -0.375
            )
        ]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
