"""`Sulfur`, ported from Dragonfly `server/block/sulfur.go`.

TODO(world-runtime): the drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .hash import HASH_SULFUR
from .model.solid import Solid as SolidModel


struct Sulfur(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
):
    """A decorative mineral block."""

    comptime BASE_HASH: UInt64 = HASH_SULFUR
    """Go `hashSulfur`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var chiseled: Bool
    """Whether the sulfur is chiseled."""

    def __init__(out self, *, chiseled: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            chiseled: Whether the sulfur is chiseled.
        """
        self.chiseled = chiseled

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
        if self.chiseled:
            return BlockState("minecraft:chiseled_sulfur")
        return BlockState("minecraft:sulfur")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(1) if self.chiseled else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Sulfur(chiseled=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Sulfur(), Sulfur(chiseled=True)]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.chiseled:
            return EncodedItem("minecraft:chiseled_sulfur", 0)
        return EncodedItem("minecraft:sulfur", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Sulfur(), Sulfur(chiseled=True)]
