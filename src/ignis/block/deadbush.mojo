"""`DeadBush`, ported from Dragonfly `server/block/deadbush.go`.

Go's `replaceable` helper (ReplaceableBy) comes with `world.Tx`. Go's
`sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes with
liquids.

TODO(world-runtime): NeighbourUpdateTick, HasLiquidDrops, UseOnBlock, BoneMeal,
FlammabilityInfo and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_DEAD_BUSH
from .model.empty import Empty as EmptyModel


struct DeadBush(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """A transparent block in the form of an aesthetic plant."""

    comptime BASE_HASH: UInt64 = HASH_DEAD_BUSH
    """Go `hashDeadBush`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `DeadBush{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:deadbush")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return DeadBush()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [DeadBush()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:deadbush", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
