"""`EndBricks`, ported from Dragonfly `server/block/end_bricks.go`.

TODO(world-runtime): the `oneOf` drops.
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
from .hash import HASH_END_BRICKS
from .model.solid import Solid as SolidModel


struct EndBricks(
    Block, Breakable, Equatable, ImplicitlyCopyable, Item, ModelledBlock
):
    """A block made from combining four end stone blocks together."""

    comptime BASE_HASH: UInt64 = HASH_END_BRICKS
    """Go `hashEndBricks`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `EndBricks{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:end_bricks")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return EndBricks()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [EndBricks()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            3, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(9)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:end_bricks", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
