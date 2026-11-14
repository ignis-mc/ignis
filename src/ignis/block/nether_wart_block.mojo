"""`NetherWartBlock`, ported from Dragonfly
`server/block/nether_wart_block.go`.

TODO(world-runtime): the drops.
"""

from ..item.item import Compostable
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    HOE_EFFECTIVE,
    new_break_info,
)
from .hash import HASH_NETHER_WART_BLOCK
from .model.solid import Solid as SolidModel


struct NetherWartBlock(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
):
    """A decorative block found in crimson forests and crafted from nether wart.
    """

    comptime BASE_HASH: UInt64 = HASH_NETHER_WART_BLOCK
    """Go `hashNetherWartBlock`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var warped: Bool
    """Whether the block is a warped wart block."""

    def __init__(out self, *, warped: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.warped = warped

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.warped:
            return BlockState("minecraft:warped_wart_block")
        return BlockState("minecraft:nether_wart_block")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.warped else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return NetherWartBlock(warped=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [NetherWartBlock(warped=True), NetherWartBlock()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(1, ALWAYS_HARVESTABLE, HOE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.warped:
            return EncodedItem("minecraft:warped_wart_block", 0)
        return EncodedItem("minecraft:nether_wart_block", 0)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.85

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [NetherWartBlock(warped=True), NetherWartBlock()]
