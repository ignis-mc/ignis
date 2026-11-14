"""`DirtPath`, ported from Dragonfly `server/block/dirt_path.go`.

TODO(world-runtime): Till, NeighbourUpdateTick and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    SHOVEL_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_DIRT_PATH
from .model.tilled_grass import TilledGrass as TilledGrassModel


struct DirtPath(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """A decorative block that can be created by using a shovel on grass or dirt.
    """

    comptime BASE_HASH: UInt64 = HASH_DIRT_PATH
    """Go `hashDirtPath`."""
    comptime ModelType = TilledGrassModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `DirtPath{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:grass_path")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return DirtPath()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [DirtPath()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.65, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> TilledGrassModel:
        """Returns the model of the block (Go `Model`)."""
        return TilledGrassModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:grass_path", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
