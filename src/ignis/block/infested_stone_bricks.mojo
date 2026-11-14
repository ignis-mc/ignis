"""`InfestedStoneBricks`, ported from Dragonfly
`server/block/infested_stone_bricks.go`.

TODO(world-runtime): the `silkTouchOnlyDrop` drops and the silverfish spawn.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_INFESTED_STONE_BRICKS
from .model.solid import Solid as SolidModel
from .stone_bricks_type import StoneBricksType, stone_bricks_types


struct InfestedStoneBricks(
    Block, Breakable, Equatable, ImplicitlyCopyable, Item, ModelledBlock
):
    """A stone bricks block that hides a silverfish."""

    comptime BASE_HASH: UInt64 = HASH_INFESTED_STONE_BRICKS
    """Go `hashInfestedStoneBricks`."""
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
        return BlockState(String(t"minecraft:infested_{self.type}"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return InfestedStoneBricks(type=StoneBricksType(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for type in stone_bricks_types():
            out.append(InfestedStoneBricks(type=type))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            0.75, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(0.75)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:infested_{self.type}"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for t in stone_bricks_types():
            out.append(Self(type=t))
        return out^
