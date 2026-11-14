"""`Skull`, ported from Dragonfly `server/block/model/skull.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos


struct Skull(BlockModel, ImplicitlyCopyable):
    """The model of a skull (Go `model.Skull`)."""

    comptime MODEL_ID: Int = 33
    """The model ID of `Skull`."""

    var direction: Face
    """The face the skull is attached to when hanging."""
    var hanging: Bool
    """Whether the skull hangs on a wall."""

    def __init__(
        out self, *, direction: Face = Face.DOWN, hanging: Bool = False
    ):
        """Creates the model; omitted fields take Go zero values."""
        self.direction = direction
        self.hanging = hanging

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        var box = BBox.box(0.25, 0, 0.25, 0.75, 0.5, 0.75)
        if not self.hanging:
            return [box]
        return [
            box.translate_towards(
                self.direction.opposite(), 0.25
            ).translate_towards(Face.UP, 0.25)
        ]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False
