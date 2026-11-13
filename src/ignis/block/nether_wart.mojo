"""`NetherWart`, ported from Dragonfly `server/block/nether_wart.go`.

TODO(world-runtime): HasLiquidDrops, RandomTick, UseOnBlock,
NeighbourUpdateTick, CompostChance, EncodeItem and the drops (fortune).
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
from .hash import HASH_NETHER_WART


struct NetherWart(
    Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser
):
    """A fungus found in the nether that is vital in the creation of potions."""

    comptime BASE_HASH: UInt64 = HASH_NETHER_WART
    """Go `hashNetherWart`."""

    var age: Int
    """The age of the nether wart, 0 to 3; 3 is fully grown."""

    def __init__(out self, *, age: Int = 0):
        """Creates the block; omitted fields take Go zero values.

        Args:
            age: The age of the nether wart, 0 to 3; 3 is fully grown.
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
            "minecraft:nether_wart",
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
        return NetherWart(age=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for age in range(4):
            out.append(NetherWart(age=age))
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
