"""`Sapling`, ported from Dragonfly `server/block/sapling.go`.

TODO(world-runtime): RandomTick, BoneMeal, grow (sapling_tree.go),
NeighbourUpdateTick, HasLiquidDrops, UseOnBlock, BoneMeal, CompostChance,
FlammabilityInfo, EncodeItem and the drops.
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
from .hash import HASH_SAPLING
from .sapling_type import SaplingType, sapling_types


struct Sapling(Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser):
    """A plant that grows into a tree."""

    comptime BASE_HASH: UInt64 = HASH_SAPLING
    """Go `hashSapling`."""

    var type: SaplingType
    """The type of the sapling."""
    var aged: Bool
    """Whether the sapling has passed its first growth stage; it grows into a tree only once it has."""

    def __init__(
        out self, *, type: SaplingType = SaplingType.OAK, aged: Bool = False
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            type: The type of the sapling.
            aged: Whether the sapling has passed its first growth stage; it grows into a tree only once it has.
        """
        self.type = type
        self.aged = aged

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
            Properties().with_bool("age_bit", self.aged),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.type.uint8())
            | (UInt64(1) if self.aged else UInt64(0)) << 4
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Sapling(
            type=SaplingType(Int(hash & 0xF)), aged=(hash >> 4) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for t in sapling_types():
            out.append(Sapling(type=t))
            out.append(Sapling(type=t, aged=True))
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
