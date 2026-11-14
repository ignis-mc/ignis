"""`Stairs`, ported from Dragonfly `server/block/stairs.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): NeighbourUpdateTick, DeriveState,
calculateCorner, continued, Model, Instrument, FlammabilityInfo, SideClosed and
the drops.
"""

from .cube.face import Face
from .cube.pos import Pos
from .cube.rotation import Rotation
from ..mgl64 import Vec3
from ..world.world import World, WorldTypes
from .block import Placement, UsableOnBlock, first_replaceable, replaceable_with
from .hash import AnyBlock

from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import BreakInfo, Breakable, new_break_info
from .cube.direction import Direction
from .hash import (
    AnyBlock,
    HASH_BAMBOO_MOSAIC,
    HASH_STAIRS,
    hash_block,
    unhash_block,
)
from .model.stair import Stair as StairModel
from .planks import Planks
from .register import break_info
from .stairs_corner import StairsCorner, stairs_corners
from .stairs_type import encode_stairs_block, stairs_blocks


struct Stairs(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    UsableOnBlock,
):
    """A block that allows entities to walk up blocks without jumping."""

    comptime BASE_HASH: UInt64 = HASH_STAIRS
    """Go `hashStairs`."""
    comptime ModelType = StairModel
    """The model type (Go `Model`)."""

    var block: AnyBlock
    """The block the stairs are made of."""
    var upside_down: Bool
    """Whether the full side of the stairs is at the top."""
    var facing: Direction
    """The direction the full side of the stairs faces."""
    var corner: StairsCorner
    """The corner the stairs form with the stairs around them."""

    def __init__(
        out self,
        *,
        block: AnyBlock,
        upside_down: Bool = False,
        facing: Direction = Direction.NORTH,
        corner: StairsCorner = StairsCorner.NONE,
    ):
        """Creates the block; `block` is required, the other fields default to Go zero values.
        """
        self.block = block
        self.upside_down = upside_down
        self.facing = facing
        self.corner = corner

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            String(t"minecraft:{encode_stairs_block(self.block)}_stairs"),
            Properties()
            .with_string("minecraft:corner", String(self.corner))
            .with_bool("upside_down_bit", self.upside_down)
            .with_int("weirdo_direction", to_stairs_direction(self.facing)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            hash_block(self.block)
            | (UInt64(1) if self.upside_down else UInt64(0)) << 32
            | UInt64(Int(self.facing)) << 33
            | UInt64(self.corner.uint8()) << 35
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Stairs(
            block=unhash_block(hash & 0xFFFFFFFF),
            upside_down=(hash >> 32) & 0x1 != 0,
            facing=Direction(Int((hash >> 33) & 0x3)),
            corner=StairsCorner(Int((hash >> 35) & 0x7)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for i in range(4):
            for upside_down in [True, False]:
                for s in stairs_blocks():
                    for corner in stairs_corners():
                        out.append(
                            Stairs(
                                block=s,
                                upside_down=upside_down,
                                facing=Direction(i),
                                corner=corner,
                            )
                        )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        var info = break_info(self.block.kind, self.block.state).value()
        return new_break_info(
            info.hardness, info.harvestable, info.effective
        ).with_blast_resistance(info.blast_resistance)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> StairModel:
        """Returns the model of the block (Go `Model`)."""
        return StairModel(
            facing=self.facing,
            upside_down=self.upside_down,
            corner=self.corner != StairsCorner.NONE,
            inner=self.corner.inner(),
            left=self.corner.left(),
        )

    def use_on_block[
        T: WorldTypes
    ](
        self,
        pos: Pos,
        face: Face,
        click: Vec3,
        user: Rotation,
        mut tx: World[T],
    ) -> List[Placement]:
        """Places the stairs facing away from the user, upside down when
        clicked on the upper half of a side or under a block (Go
        `UseOnBlock`; the corner is not derived from neighbours yet)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var f = at.value()[1]
        var b = self.copy()
        b.facing = user.direction()
        if f == Face.DOWN or (click.y() > 0.5 and f != Face.UP):
            b.upside_down = True
        return [
            Placement(at.value()[0], AnyBlock(Self.BASE_HASH, b.hash()), False)
        ]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(
            String(t"minecraft:{encode_stairs_block(self.block)}_stairs"), 0
        )

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info of the block it is made of (Go `FuelInfo`)."""
        if case .Some(p) = self.block.get[Planks]():
            return p.fuel_info()
        if self.block.kind == HASH_BAMBOO_MOSAIC:
            # Go `BambooMosaic.FuelInfo`.
            return FuelInfo(15000)
        return FuelInfo()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in stairs_blocks():
            out.append(Stairs(block=v))
        return out^


def to_stairs_direction(v: Direction) -> Int32:
    """Converts a direction to the `weirdo_direction` property (Go
    `toStairsDirection`)."""
    return Int32(3 - Int(v))
