"""`Thin`, ported from Dragonfly `server/block/model/thin.go`.

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
from .wall import Wall


@fieldwise_init
struct Thin(BlockModel, Connector, ImplicitlyCopyable):
    """The model of panes and bars, which connect to the blocks around them (Go `model.Thin`).
    """

    comptime MODEL_ID: Int = 37
    """The model ID of `Thin`."""

    def bbox[S: BlockSource](self, pos: Pos, src: S) -> List[BBox]:
        """Returns the boxes of the model (Go `BBox`)."""
        var boxes = List[BBox](capacity=2)
        var connect_west = self.connects(pos, Face.WEST, src)
        var connect_east = self.connects(pos, Face.EAST, src)
        if connect_west or connect_east:
            var box = BBox.box(0, 0, 0, 1, THIN_HEIGHT, 1).stretch(
                Axis.Z, -THIN_INSET
            )
            if not connect_west:
                box = box.extend_towards(Face.WEST, -THIN_INSET)
            elif not connect_east:
                box = box.extend_towards(Face.EAST, -THIN_INSET)
            boxes.append(box)
        var connect_north = self.connects(pos, Face.NORTH, src)
        var connect_south = self.connects(pos, Face.SOUTH, src)
        if connect_north or connect_south:
            var box = BBox.box(0, 0, 0, 1, THIN_HEIGHT, 1).stretch(
                Axis.X, -THIN_INSET
            )
            if not connect_north:
                box = box.extend_towards(Face.NORTH, -THIN_INSET)
            elif not connect_south:
                box = box.extend_towards(Face.SOUTH, -THIN_INSET)
            boxes.append(box)
        if len(boxes) == 0:
            boxes.append(
                BBox.box(0, 0, 0, 1, THIN_HEIGHT, 1)
                .stretch(Axis.X, -THIN_INSET)
                .stretch(Axis.Z, -THIN_INSET)
            )
        return boxes^

    def face_solid[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether a face is solid (Go `FaceSolid`)."""
        return face == Face.DOWN

    def connects[S: BlockSource](self, pos: Pos, face: Face, src: S) -> Bool:
        """Reports whether the block connects to the block on a face: another
        thin block, a wall or a solid face (Go `Connects`)."""
        var side_pos = pos.side(face)
        var side = block_at(src, side_pos)
        return (
            Bool(block_model_as[Thin](side))
            or Bool(block_model_as[Wall](side))
            or block_model_face_solid(side, side_pos, face.opposite(), src)
        )


comptime THIN_HEIGHT = 1.0
"""The height of a thin block's boxes (Go `thinHeight`)."""
comptime THIN_INSET = 7.0 / 16.0
"""How far a thin block's middle is from the sides (Go `thinInset`)."""
