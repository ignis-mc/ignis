"""`SoulSoil`, ported from Dragonfly `server/block/soul_soil.go`.

TODO(world-runtime): the drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    SHOVEL_EFFECTIVE,
    new_break_info,
)
from .hash import AnyBlock, HASH_NETHER_SPROUTS, HASH_SOUL_SOIL
from .model.solid import Solid as SolidModel
from .dirt import Soil


struct SoulSoil(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    Soil,
):
    """A block naturally found only in the soul sand valley."""

    comptime BASE_HASH: UInt64 = HASH_SOUL_SOIL
    """Go `hashSoulSoil`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `SoulSoil{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:soul_soil")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return SoulSoil()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [SoulSoil()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.5, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:soul_soil", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def soil_for(self, b: AnyBlock) -> Bool:
        """Grows nether sprouts (Go `SoilFor`)."""
        var k = b.kind
        return k == HASH_NETHER_SPROUTS
