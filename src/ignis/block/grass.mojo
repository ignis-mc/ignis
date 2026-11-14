"""Grass blocks, ported from Dragonfly `server/block/grass.go`.

TODO(world-runtime): RandomTick, BoneMeal, SoilFor, Till, Shovel,
CompostChance.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from ..item.stack import Stack
from ..item.tool import ToolInfo
from .dirt import Dirt
from .break_info import (
    ALWAYS_HARVESTABLE,
    SHOVEL_EFFECTIVE,
    BreakInfo,
    Breakable,
    Dropper,
    new_break_info,
)
from .hash import HASH_GRASS
from .model.solid import Solid as SolidModel


@fieldwise_init
struct Grass(
    Block,
    Breakable,
    Dropper,
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
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            `minecraft:grass_block` without properties.
        """
        return BlockState("minecraft:grass_block")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            0: grass has no state.
        """
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            Grass.
        """
        return Grass()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `RegisterBlock(Grass{})`).

        Returns:
            Grass.
        """
        return [Grass()]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`).

        Returns:
            `minecraft:grass_block`, metadata 0.
        """
        return EncodedItem("minecraft:grass_block", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `RegisterItem` calls
        in `register.go`).

        Returns:
            Grass.
        """
        return [Grass()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.6, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()

    def drops(self, tool: ToolInfo, silk_touch: Bool) -> List[Stack]:
        """Drops dirt, itself with silk touch (Go `silkTouchOneOf`)."""
        if silk_touch:
            return [Stack(self, 1)]
        return [Stack(Dirt(), 1)]
