"""`ShelfMushroom`, ported from Dragonfly `server/block/shelf_mushroom.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, BoneMeal, Model and the
drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_SHELF_MUSHROOM
from .model.shelf_mushroom import ShelfMushroom as ShelfMushroomModel
from .liquid import LiquidRemovable


struct ShelfMushroom(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidRemovable,
    ModelledBlock,
):
    """A mushroom that grows on the side of logs."""

    comptime BASE_HASH: UInt64 = HASH_SHELF_MUSHROOM
    """Go `hashShelfMushroom`."""
    comptime ModelType = ShelfMushroomModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the mushroom faces, away from the block it is attached to."""
    var large: Bool
    """Whether the mushroom has grown to its large stage."""

    def __init__(
        out self, *, facing: Direction = Direction.NORTH, large: Bool = False
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.large = large

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:shelf_mushroom",
            Properties()
            .with_string("minecraft:cardinal_direction", String(self.facing))
            .with_int("growth", Int32(1) if self.large else Int32(0)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.large else UInt64(0)) << 2
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return ShelfMushroom(
            facing=Direction(Int(hash & 0x3)), large=(hash >> 2) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for d in directions():
            out.append(ShelfMushroom(facing=d))
            out.append(ShelfMushroom(facing=d, large=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> ShelfMushroomModel:
        """Returns the model of the block (Go `Model`)."""
        return ShelfMushroomModel(facing=self.facing, large=self.large)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:shelf_mushroom", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def has_liquid_drops(self) -> Bool:
        """Returns True (Go `HasLiquidDrops`)."""
        return True
