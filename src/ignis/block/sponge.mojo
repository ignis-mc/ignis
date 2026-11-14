"""`Sponge`, ported from Dragonfly `server/block/sponge.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, absorbWater and the
drops.
"""

from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    new_break_info,
)
from .hash import HASH_SPONGE
from .model.solid import Solid as SolidModel


struct Sponge(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    Smeltable,
):
    """A block that can be used to remove water around itself when placed."""

    comptime BASE_HASH: UInt64 = HASH_SPONGE
    """Go `hashSponge`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var wet: Bool
    """Whether the sponge is wet."""

    def __init__(out self, *, wet: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            wet: Whether the sponge is wet.
        """
        self.wet = wet

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state.
        """
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        if self.wet:
            return BlockState("minecraft:wet_sponge")
        return BlockState("minecraft:sponge")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(1) if self.wet else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Sponge(wet=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Sponge(wet=True), Sponge()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.6, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.wet:
            return EncodedItem("minecraft:wet_sponge", 0)
        return EncodedItem("minecraft:sponge", 0)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        if self.wet:
            return SmeltInfo(Stack(Sponge(), 1), 0.15)
        return SmeltInfo()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Sponge(wet=True), Sponge()]
