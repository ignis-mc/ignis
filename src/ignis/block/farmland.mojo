"""`Farmland`, ported from Dragonfly `server/block/farmland.go`.

TODO(world-runtime): SoilFor, NeighbourUpdateTick, RandomTick (with hydrated),
EntityLand and the drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    SHOVEL_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_FARMLAND
from .model.tilled_grass import TilledGrass as TilledGrassModel


struct Farmland(
    Block, Breakable, Equatable, ImplicitlyCopyable, Item, ModelledBlock
):
    """A block that crops are grown on, created by using a hoe on dirt or grass.
    """

    comptime BASE_HASH: UInt64 = HASH_FARMLAND
    """Go `hashFarmland`."""
    comptime ModelType = TilledGrassModel
    """The model type (Go `Model`)."""

    var hydration: Int
    """How hydrated the farmland is, 0 to 7."""

    def __init__(out self, *, hydration: Int = 0):
        """Creates the block; omitted fields take Go zero values.

        Args:
            hydration: How hydrated the farmland is, 0 to 7.
        """
        self.hydration = hydration

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
        return BlockState(
            "minecraft:farmland",
            Properties().with_int("moisturized_amount", Int32(self.hydration)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.hydration)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Farmland(hydration=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for hydration in range(8):
            out.append(Farmland(hydration=hydration))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.6, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> TilledGrassModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return TilledGrassModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:farmland", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
