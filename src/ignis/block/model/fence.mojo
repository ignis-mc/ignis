"""`Fence`, ported from Dragonfly `server/block/model/fence.go`.

Go `world.Block`s are runtime IDs here; the neighbour's model is found through `ignis.block.register`.
"""

from ...world.block_model import BlockModel
from ..connections import Connector
from ...world.block_source import BlockSource
from ..cube.axis import Axis
from ..cube.bbox import BBox
from ..cube.face import Face
from ..cube.pos import Pos
from ..register import block_at, block_model_as, block_model_face_solid
from .fence_gate import FenceGate


struct Fence(BlockModel, Connector, ImplicitlyCopyable):
    """The model of a fence, which connects to the blocks around it (Go `model.Fence`).
    """

    comptime MODEL_ID: Int = 21
    """The model ID of `Fence`."""

    var wood: Bool
    """Whether the fence is wooden; wooden and nether brick fences do not connect."""

    def __init__(out self, *, wood: Bool = False):
        """Creates the model; omitted fields take Go zero values."""
        self.wood = wood

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        var boxes = List[BBox](capacity=2)
        var connect_west = self.connects(pos, Face.WEST, src)
        var connect_east = self.connects(pos, Face.EAST, src)
        var connect_north = self.connects(pos, Face.NORTH, src)
        var connect_south = self.connects(pos, Face.SOUTH, src)
        if connect_west or connect_east:
            var side_box = BBox.box(0, 0, 0, 1, FENCE_HEIGHT, 1).stretch(
                Axis.Z, -FENCE_INSET
            )
            if connect_west:
                boxes.append(side_box.extend_towards(Face.EAST, -FENCE_INSET))
            if connect_east:
                boxes.append(side_box.extend_towards(Face.WEST, -FENCE_INSET))
        if connect_north or connect_south:
            var side_box = BBox.box(0, 0, 0, 1, FENCE_HEIGHT, 1).stretch(
                Axis.X, -FENCE_INSET
            )
            if connect_north:
                boxes.append(side_box.extend_towards(Face.SOUTH, -FENCE_INSET))
            if connect_south:
                boxes.append(side_box.extend_towards(Face.NORTH, -FENCE_INSET))
        if len(boxes) == 0:
            boxes.append(
                BBox.box(
                    FENCE_INSET,
                    0,
                    FENCE_INSET,
                    1 - FENCE_INSET,
                    FENCE_HEIGHT,
                    1 - FENCE_INSET,
                )
            )
        return boxes^

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return face == Face.DOWN or face == Face.UP

    def connects[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether the fence connects to the block on a face: a fence
        of the same kind, a solid face or a fence gate (Go `Connects`)."""
        var side_pos = pos.side(face)
        var side = block_at(src, side_pos)
        if case .Some(fence) = block_model_as[Fence](side):
            if fence.wood == self.wood:
                return True
        if block_model_face_solid(side, side_pos, face.opposite(), src):
            return True
        return Bool(block_model_as[FenceGate](side))


comptime FENCE_HEIGHT = 1.5
"""The height of a fence's collision boxes (Go `fenceHeight`)."""
comptime FENCE_INSET = 0.375
"""How far a fence post is from the sides of its block (Go `fenceInset`)."""
