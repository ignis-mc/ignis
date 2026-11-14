"""`Shulker`, ported from Dragonfly `server/block/model/shulker.go`."""

from ...world.block_model import BlockModel
from ...world.block_source import BlockSource
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos
from .solid import FULL


struct Shulker(BlockModel, ImplicitlyCopyable):
    """The model of a shulker box, which grows as its lid opens (Go `model.Shulker`).
    """

    comptime MODEL_ID: Int = 32
    """The model ID of `Shulker`."""

    var facing: Face
    """The direction the lid opens to."""
    var progress: Int32
    """How far the lid is open, 0 to 10."""

    def __init__(out self, *, facing: Face = Face.DOWN, progress: Int32 = 0):
        """Creates the model; omitted fields take Go zero values."""
        self.facing = facing
        self.progress = progress

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        return [
            FULL.extend_towards(
                self.facing, shulker_physical_peak(self.progress)
            )
        ]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return False


def shulker_physical_peak(progress: Int32) -> Float64:
    """Returns how far an opening shulker box lid sticks out of its block
    (Go `ShulkerPhysicalPeak`)."""
    var t = Float64(progress) / 10.0
    return (1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)) * 0.5
