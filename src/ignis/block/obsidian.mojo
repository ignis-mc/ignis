"""`Obsidian`, ported from Dragonfly `server/block/obsidian.go`.

TODO(world-runtime): Frame, SupportsEndCrystal, EncodeItem, SmeltInfo and
the drops.
"""

from ..world.block import Block, LightEmitter
from ..world.block_state import BlockState
from .break_info import (
    HARVEST_LEVEL_DIAMOND,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
    pickaxe_harvestable_from,
)
from .hash import HASH_OBSIDIAN


struct Obsidian(Block, Breakable, Equatable, ImplicitlyCopyable, LightEmitter):
    """A dark purple block known for its high blast resistance and strength, most commonly found when
    water flows over lava."""

    comptime BASE_HASH: UInt64 = HASH_OBSIDIAN
    """Go `hashObsidian`."""

    var crying: Bool
    """Whether the obsidian is crying obsidian."""

    def __init__(out self, *, crying: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            crying: Whether the obsidian is crying obsidian.
        """
        self.crying = crying

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
        if self.crying:
            return BlockState("minecraft:crying_obsidian")
        return BlockState("minecraft:obsidian")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(1) if self.crying else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Obsidian(crying=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Obsidian(crying=True), Obsidian()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            35,
            pickaxe_harvestable_from(HARVEST_LEVEL_DIAMOND),
            PICKAXE_EFFECTIVE,
        ).with_blast_resistance(1200)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        return 10 if self.crying else 0
