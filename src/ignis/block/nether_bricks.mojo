"""`NetherBricks`, ported from Dragonfly `server/block/nether_bricks.go`.

TODO(world-runtime): the `oneOf` drops.
"""

from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .hash import HASH_NETHER_BRICKS
from .model.solid import Solid as SolidModel
from .nether_bricks_type import NetherBricksType, nether_bricks_types


struct NetherBricks(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    Smeltable,
):
    """A block made from four nether bricks."""

    comptime BASE_HASH: UInt64 = HASH_NETHER_BRICKS
    """Go `hashNetherBricks`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var type: NetherBricksType
    """The type of nether bricks."""

    def __init__(out self, *, type: NetherBricksType = NetherBricksType.NORMAL):
        """Creates the block; omitted fields take Go zero values."""
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(String(t"minecraft:{self.type}"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return NetherBricks(type=NetherBricksType(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for type in nether_bricks_types():
            out.append(NetherBricks(type=type))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            2, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.type}"), 0)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        if self.type == NetherBricksType.NORMAL:
            return SmeltInfo(
                Stack(NetherBricks(type=NetherBricksType.CRACKED), 1), 0.1
            )
        return SmeltInfo()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in nether_bricks_types():
            out.append(NetherBricks(type=v))
        return out^
