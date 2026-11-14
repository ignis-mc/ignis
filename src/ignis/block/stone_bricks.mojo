"""`StoneBricks`, ported from Dragonfly `server/block/stone_bricks.go`.

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
from .hash import HASH_STONE_BRICKS
from .model.solid import Solid as SolidModel
from .stone_bricks_type import StoneBricksType, stone_bricks_types


struct StoneBricks(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    Smeltable,
):
    """A decorative block made from stone."""

    comptime BASE_HASH: UInt64 = HASH_STONE_BRICKS
    """Go `hashStoneBricks`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var type: StoneBricksType
    """The type of stone bricks."""

    def __init__(out self, *, type: StoneBricksType = StoneBricksType.NORMAL):
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
        return StoneBricks(type=StoneBricksType(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for type in stone_bricks_types():
            out.append(StoneBricks(type=type))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.type}"), 0)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        if self.type == StoneBricksType.NORMAL:
            return SmeltInfo(
                Stack(StoneBricks(type=StoneBricksType.CRACKED), 1), 0.1
            )
        return SmeltInfo()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in stone_bricks_types():
            out.append(StoneBricks(type=v))
        return out^
