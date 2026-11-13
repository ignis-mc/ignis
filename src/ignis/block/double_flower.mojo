"""`DoubleFlower`, ported from Dragonfly `server/block/double_flower.go`.

TODO(world-runtime): NeighbourUpdateTick, HasLiquidDrops, UseOnBlock,
BoneMeal, CompostChance, FlammabilityInfo, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .double_flower_type import DoubleFlowerType, double_flower_types
from .hash import HASH_DOUBLE_FLOWER


struct DoubleFlower(
    Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser
):
    """A two block high flower consisting of an upper and lower part."""

    comptime BASE_HASH: UInt64 = HASH_DOUBLE_FLOWER
    """Go `hashDoubleFlower`."""

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
