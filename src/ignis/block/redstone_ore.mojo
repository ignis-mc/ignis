"""`RedstoneOre`, ported from Dragonfly `server/block/redstone_ore.go`.

TODO(world-runtime): Activate, Punch, EntityStepOn, RandomTick, EncodeItem,
SmeltInfo and the drops.
"""

from ..world.block import Block, LightEmitter
from ..world.block_state import BlockState
from .break_info import (
    HARVEST_LEVEL_IRON,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
    pickaxe_harvestable_from,
)
from .hash import HASH_REDSTONE_ORE
from .ore_type import OreType, ore_types


struct RedstoneOre(
    Block, Breakable, Equatable, ImplicitlyCopyable, LightEmitter
):
    """A common ore that lights up when touched."""

    comptime BASE_HASH: UInt64 = HASH_REDSTONE_ORE
    """Go `hashRedstoneOre`."""

    var type: OreType
    """The rock the ore is embedded in."""
    var lit: Bool
    """Whether the ore is lit up."""

    def __init__(out self, *, type: OreType = OreType.STONE, lit: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            type: The rock the ore is embedded in.
            lit: Whether the ore is lit up.
        """
        self.type = type
        self.lit = lit

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
        var lit = "lit_" if self.lit else ""
        return BlockState(
            String(t"minecraft:{lit}{self.type.prefix()}redstone_ore")
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.type.uint8())
            | (UInt64(1) if self.lit else UInt64(0)) << 1
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return RedstoneOre(
            type=OreType(Int(hash & 0x1)), lit=(hash >> 1) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for t in ore_types():
            out.append(RedstoneOre(type=t))
            out.append(RedstoneOre(type=t, lit=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return (
            new_break_info(
                self.type.hardness(),
                pickaxe_harvestable_from(HARVEST_LEVEL_IRON),
                PICKAXE_EFFECTIVE,
            )
            .with_xp_drop_range(1, 5)
            .with_blast_resistance(3)
        )

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        return 9 if self.lit else 0
