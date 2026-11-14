"""`Cobweb`, ported from Dragonfly `server/block/cobweb.go`.

TODO(world-runtime): Cobweb, EntityInside and the drops (string with shears).
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    SHEARS_EFFECTIVE,
    SWORD_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_COBWEB
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable


struct Cobweb(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidRemovable,
    ModelledBlock,
):
    """A block that slows down entities moving through it."""

    comptime BASE_HASH: UInt64 = HASH_COBWEB
    """Go `hashCobweb`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `Cobweb{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:web")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Cobweb()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Cobweb()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            4, ALWAYS_HARVESTABLE, SWORD_EFFECTIVE | SHEARS_EFFECTIVE
        )

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:web", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def has_liquid_drops(self) -> Bool:
        """Returns True (Go `HasLiquidDrops`)."""
        return True
