"""Grass blocks, ported from Dragonfly `server/block/grass.go`.

TODO(world-runtime): RandomTick, BoneMeal, SoilFor, Till, Shovel,
CompostChance and the drops.
"""

from ..item.item import Compostable
from ..world.block import Block
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
from .hash import HASH_GRASS
from .model.solid import Solid as SolidModel


@fieldwise_init
struct Grass(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
):
    """Grass blocks generate abundantly across the surface of the world."""

    comptime BASE_HASH: UInt64 = HASH_GRASS
    """Go `hashGrass`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:grass_block")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Grass()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `RegisterBlock(Grass{})`)."""
        return [Grass()]

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`): 0.3."""
        return 0.3

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:grass_block", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `RegisterItem` calls
        in `register.go`)."""
        return [Grass()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.6, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()
