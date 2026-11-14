"""`Cactus`, ported from Dragonfly `server/block/cactus.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, RandomTick, EntityInside,
DamageSource, CanDisplace, SideClosed, Model and the drops.
"""

from ..item.item import Compostable
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_CACTUS
from .model.cactus import Cactus as CactusModel


struct Cactus(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """A plant block that generates naturally in dry areas and causes damage."""

    comptime BASE_HASH: UInt64 = HASH_CACTUS
    """Go `hashCactus`."""
    comptime ModelType = CactusModel
    """The model type (Go `Model`)."""

    var age: Int
    """The growth state, 0 to 15."""

    def __init__(out self, *, age: Int = 0):
        """Creates the block; omitted fields take Go zero values.

        Args:
            age: The growth state, 0 to 15.
        """
        self.age = age

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
            "minecraft:cactus",
            Properties().with_int("age", Int32(self.age)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.age)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Cactus(age=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for age in range(16):
            out.append(Cactus(age=age))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.4, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> CactusModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return CactusModel()

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.5

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:cactus", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
