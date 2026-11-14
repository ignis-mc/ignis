"""`InfestedCobblestone`, ported from Dragonfly
`server/block/infested_cobblestone.go`.

TODO(world-runtime): the `silkTouchOnlyDrop` drops and the silverfish spawn.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    Dropper,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .hash import HASH_INFESTED_COBBLESTONE
from .model.solid import Solid as SolidModel
from ..item.stack import Stack
from ..item.tool import ToolInfo


struct InfestedCobblestone(
    Block,
    Breakable,
    Dropper,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
):
    """A cobblestone block that hides a silverfish."""

    comptime BASE_HASH: UInt64 = HASH_INFESTED_COBBLESTONE
    """Go `hashInfestedCobblestone`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `InfestedCobblestone{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:infested_cobblestone")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return InfestedCobblestone()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [InfestedCobblestone()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            1, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(0.75)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:infested_cobblestone", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def drops(self, tool: ToolInfo, silk_touch: Bool) -> List[Stack]:
        """Drops itself only with silk touch (Go `silkTouchOnlyDrop`)."""
        if silk_touch:
            return [Stack(self, 1)]
        return []
