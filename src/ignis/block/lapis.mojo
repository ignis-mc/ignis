"""`Lapis`, ported from Dragonfly `server/block/lapis.go`.

TODO(world-runtime): the drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    HARVEST_LEVEL_STONE,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
    pickaxe_harvestable_from,
)
from .hash import HASH_LAPIS
from .model.solid import Solid as SolidModel


struct Lapis(
    Block, Breakable, Equatable, ImplicitlyCopyable, Item, ModelledBlock
):
    """A decorative mineral block crafted from lapis lazuli."""

    comptime BASE_HASH: UInt64 = HASH_LAPIS
    """Go `hashLapis`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `Lapis{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:lapis_block")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Lapis()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Lapis()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            3, pickaxe_harvestable_from(HARVEST_LEVEL_STONE), PICKAXE_EFFECTIVE
        )

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:lapis_block", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
