"""`NetherSprouts`, ported from Dragonfly `server/block/nether_sprouts.go`.

Go's `replaceable` helper is `Replaceable`.

TODO(world-runtime): NeighbourUpdateTick, HasLiquidDrops, UseOnBlock, BoneMeal,
FlammabilityInfo and the drops.
"""

from ..item.item import Compostable
from ..item.tool import TYPE_SHEARS
from .block import Replaceable
from .hash import AnyBlock
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    ToolFilter,
    new_break_info,
)
from .hash import HASH_NETHER_SPROUTS
from .model.empty import Empty as EmptyModel


struct NetherSprouts(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    Replaceable,
):
    """A non-solid plant block that generates in warped forests."""

    comptime BASE_HASH: UInt64 = HASH_NETHER_SPROUTS
    """Go `hashNetherSprouts`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `NetherSprouts{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:nether_sprouts")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return NetherSprouts()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [NetherSprouts()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0, ToolFilter(TYPE_SHEARS), NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def replaceable_by(self, b: AnyBlock) -> Bool:
        """Any block replaces it (Go's embedded `replaceable`)."""
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:nether_sprouts", 0)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.5

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
