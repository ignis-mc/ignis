"""`EmeraldOre`, ported from Dragonfly `server/block/emerald_ore.go`.

TODO(world-runtime): EncodeItem, SmeltInfo and the drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from .break_info import (
    HARVEST_LEVEL_IRON,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
    pickaxe_harvestable_from,
)
from .hash import HASH_EMERALD_ORE
from .model.solid import Solid as SolidModel
from .ore_type import OreType, ore_types


struct EmeraldOre(
    Block, Breakable, Equatable, ImplicitlyCopyable, ModelledBlock
):
    """An ore generating in mountain biomes."""

    comptime BASE_HASH: UInt64 = HASH_EMERALD_ORE
    """Go `hashEmeraldOre`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var type: OreType
    """The rock the ore is embedded in."""

    def __init__(out self, *, type: OreType = OreType.STONE):
        """Creates the block; omitted fields take Go zero values.

        Args:
            type: The rock the ore is embedded in.
        """
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
        return BlockState(String(t"minecraft:{self.type.prefix()}emerald_ore"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return EmeraldOre(type=OreType(Int(hash & 0x1)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for type in ore_types():
            out.append(EmeraldOre(type=type))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        var i = new_break_info(
            self.type.hardness(),
            pickaxe_harvestable_from(HARVEST_LEVEL_IRON),
            PICKAXE_EFFECTIVE,
        ).with_xp_drop_range(3, 7)
        if self.type == OreType.DEEPSLATE:
            i = i.with_blast_resistance(3)
        return i

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()
