"""`PinkPetals`, ported from Dragonfly `server/block/pink_petals.go`.

TODO(world-runtime): NeighbourUpdateTick, HasLiquidDrops, UseOnBlock, BoneMeal,
FlammabilityInfo and the drops.
"""

from ..item.item import Compostable
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_PINK_PETALS
from .model.empty import Empty as EmptyModel


struct PinkPetals(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """A decorative block that generates in cherry grove biomes."""

    comptime BASE_HASH: UInt64 = HASH_PINK_PETALS
    """Go `hashPinkPetals`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var additional_count: Int
    """The number of additional petals, 0 to 7; only 0 to 3 occur in-game."""
    var facing: Direction
    """The direction the petals face, opposite to the placing player."""

    def __init__(
        out self,
        *,
        additional_count: Int = 0,
        facing: Direction = Direction.NORTH,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            additional_count: The number of additional petals, 0 to 7; only 0 to 3 occur in-game.
            facing: The direction the petals face, opposite to the placing player.
        """
        self.additional_count = additional_count
        self.facing = facing

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
            "minecraft:pink_petals",
            Properties()
            .with_int("growth", Int32(self.additional_count))
            .with_string("minecraft:cardinal_direction", String(self.facing)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.additional_count) | UInt64(Int(self.facing)) << 8

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return PinkPetals(
            additional_count=Int(hash & 0xFF),
            facing=Direction(Int((hash >> 8) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for additional_count in range(8):
            for facing in directions():
                out.append(
                    PinkPetals(additional_count=additional_count, facing=facing)
                )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return EmptyModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:pink_petals", 0)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.3

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
