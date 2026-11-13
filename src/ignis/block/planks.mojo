"""`Planks`, ported from Dragonfly `server/block/planks.go`.

TODO(world-runtime): EncodeItem, FlammabilityInfo, FuelInfo and the drops,
RepairsWoodTools.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_PLANKS
from .model.solid import Solid as SolidModel
from .wood_type import WoodType, wood_types


struct Planks(Block, Breakable, Equatable, ImplicitlyCopyable, ModelledBlock):
    """Common blocks used in crafting recipes, made by crafting logs into planks.
    """

    comptime BASE_HASH: UInt64 = HASH_PLANKS
    """Go `hashPlanks`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var wood: WoodType
    """The type of wood of the planks."""

    def __init__(out self, *, wood: WoodType = WoodType.OAK):
        """Creates the block; omitted fields take Go zero values.

        Args:
            wood: The type of wood of the planks.
        """
        self.wood = wood

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
        return BlockState(String(t"minecraft:{self.wood}_planks"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.wood.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Planks(wood=WoodType(Int(hash & 0xF)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for wood in wood_types():
            out.append(Planks(wood=wood))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            2, ALWAYS_HARVESTABLE, AXE_EFFECTIVE
        ).with_blast_resistance(3)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()
