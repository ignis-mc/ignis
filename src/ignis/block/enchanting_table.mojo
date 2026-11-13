"""`EnchantingTable`, ported from Dragonfly
`server/block/enchanting_table.go`.

Go's `sourceWaterDisplacer` makes the table a `LiquidDisplacer`; that trait
comes with liquids.

TODO(world-runtime): Model, SideClosed, Activate, EncodeNBT, DecodeNBT,
EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_state import BlockState
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_ENCHANTING_TABLE


struct EnchantingTable(
    Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser, LightEmitter
):
    """A block that allows players to spend their experience point levels to enchant tools, weapons,
    books, armour, and certain other items."""

    comptime BASE_HASH: UInt64 = HASH_ENCHANTING_TABLE
    """Go `hashEnchantingTable`."""

    def __init__(out self):
        """Creates the block (Go `EnchantingTable{}`)."""
        pass

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
        return BlockState("minecraft:enchanting_table")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return EnchantingTable()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [EnchantingTable()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(1200)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        return 7

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
