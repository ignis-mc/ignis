"""Block models, ported from Dragonfly `server/world/block_model.go`.

Go's `world.Block` interface has a `Model() BlockModel` method. Here a block
type with a model conforms to `ModelledBlock` and names its model type, and
the dispatchers in `ignis.block.register` reach the model of a block of
unknown type. Each model type has a `MODEL_ID`, which takes the place of
Go's type assertions on `BlockModel` values (`m.(model.Fence)`).
"""

from ..block.cube.bbox import BBox
from ..block.cube.face import Face
from ..block.cube.pos import Pos
from ..mgl64 import Vec3
from .block import Block
from .block_source import BlockSource


trait BlockModel(Copyable, Deinitable):
    """The collision shape of a block (Go `world.BlockModel`)."""

    comptime MODEL_ID: Int
    """Distinguishes model types; unique per type."""

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes that make up the model, relative to the block's
        position (Go `BBox`)."""
        ...

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face of the block is solid, so that other blocks
        can attach to it (Go `FaceSolid`)."""
        ...


trait ModelledBlock(Block):
    """A block with a model (Go `world.Block.Model`)."""

    comptime ModelType: BlockModel
    """The type of the block's model."""

    def model(self) -> Self.ModelType:
        """Returns the model of the block (Go `Model`)."""
        ...


@fieldwise_init
struct UnknownModel(BlockModel, ImplicitlyCopyable):
    """The model of a block without a type: a full solid cube (Go
    `unknownModel`)."""

    comptime MODEL_ID: Int = 0
    """The model ID of unknown blocks."""

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns a full cube (Go `BBox`)."""
        return [BBox(Vec3(0, 0, 0), Vec3(1, 1, 1))]

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports every face as solid (Go `FaceSolid`)."""
        return True
