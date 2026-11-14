"""`RawGold`, ported from Dragonfly `server/block/raw_gold.go`.

TODO(world-runtime): the drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    HARVEST_LEVEL_IRON,
    PICKAXE_EFFECTIVE,
    new_break_info,
    pickaxe_harvestable_from,
)
from .hash import HASH_RAW_GOLD
from .model.solid import Solid as SolidModel


struct RawGold(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
):
    """A raw metal block equivalent to nine raw gold."""

    comptime BASE_HASH: UInt64 = HASH_RAW_GOLD
    """Go `hashRawGold`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `RawGold{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:raw_gold_block")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return RawGold()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [RawGold()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            5, pickaxe_harvestable_from(HARVEST_LEVEL_IRON), PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:raw_gold_block", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
