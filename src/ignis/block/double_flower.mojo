"""`DoubleFlower`, ported from Dragonfly `server/block/double_flower.go`.

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
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .double_flower_type import DoubleFlowerType, double_flower_types
from .hash import HASH_DOUBLE_FLOWER
from .model.empty import Empty as EmptyModel


struct DoubleFlower(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """A two block high flower consisting of an upper and lower part."""

    comptime BASE_HASH: UInt64 = HASH_DOUBLE_FLOWER
    """Go `hashDoubleFlower`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var upper_part: Bool
    """Whether this is the upper part of the plant."""
    var type: DoubleFlowerType
    """The type of the double flower."""

    def __init__(
        out self,
        *,
        upper_part: Bool = False,
        type: DoubleFlowerType = DoubleFlowerType.SUNFLOWER,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            upper_part: Whether this is the upper part of the plant.
            type: The type of the double flower.
        """
        self.upper_part = upper_part
        self.type = type

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
            String(t"minecraft:{self.type}"),
            Properties().with_bool("upper_block_bit", self.upper_part),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (UInt64(1) if self.upper_part else UInt64(0)) | UInt64(
            self.type.uint8()
        ) << 1

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return DoubleFlower(
            upper_part=hash & 0x1 != 0,
            type=DoubleFlowerType(Int((hash >> 1) & 0x7)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for d in double_flower_types():
            out.append(DoubleFlower(type=d, upper_part=True))
            out.append(DoubleFlower(type=d, upper_part=False))
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

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.65

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.type}"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for f in double_flower_types():
            out.append(Self(type=f))
        return out^
