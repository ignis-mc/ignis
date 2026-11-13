"""Grass blocks, ported from Dragonfly `server/block/grass.go`.

TODO(world-runtime): RandomTick, BoneMeal, SoilFor, Till, Shovel,
CompostChance, EncodeItem and the drops.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    SHOVEL_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_GRASS


@fieldwise_init
struct Grass(Block, Breakable, Equatable, ImplicitlyCopyable):
    """Grass blocks generate abundantly across the surface of the world."""

    comptime BASE_HASH: UInt64 = HASH_GRASS
    """Go `hashGrass`."""

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            `minecraft:grass_block` without properties.
        """
        return BlockState("minecraft:grass_block")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            0: grass has no state.
        """
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            Grass.
        """
        return Grass()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `RegisterBlock(Grass{})`).

        Returns:
            Grass.
        """
        return [Grass()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.6, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)
