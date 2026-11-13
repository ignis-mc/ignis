"""`BambooSapling`, ported from Dragonfly `server/block/bamboo_sapling.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, RandomTick, BoneMeal,
FuelInfo, FlammabilityInfo, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_BAMBOO_SAPLING
from .model.empty import Empty as EmptyModel


struct BambooSapling(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A sapling that grows into bamboo."""

    comptime BASE_HASH: UInt64 = HASH_BAMBOO_SAPLING
    """Go `hashBambooSapling`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var ready: Bool
    """Whether the sapling is ready to grow."""

    def __init__(out self, *, ready: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            ready: Whether the sapling is ready to grow.
        """
        self.ready = ready

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
            "minecraft:bamboo_sapling",
            Properties().with_byte("age_bit", UInt8(self.ready)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(1) if self.ready else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return BambooSapling(ready=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [BambooSapling(ready=False), BambooSapling(ready=True)]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            0, ALWAYS_HARVESTABLE, AXE_EFFECTIVE
        ).with_blast_resistance(1)

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
