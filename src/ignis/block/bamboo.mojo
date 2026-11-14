"""`Bamboo`, ported from Dragonfly `server/block/bamboo.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, RandomTick, BoneMeal,
grow, Model, FuelInfo, FlammabilityInfo, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .bamboo_leaf_size import BambooLeafSize, bamboo_leaf_sizes
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_BAMBOO
from .model.bamboo import Bamboo as BambooModel


struct Bamboo(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A woody plant that grows quickly."""

    comptime BASE_HASH: UInt64 = HASH_BAMBOO
    """Go `hashBamboo`."""
    comptime ModelType = BambooModel
    """The model type (Go `Model`)."""

    var ready: Bool
    """Whether the bamboo is ready to grow."""
    var thick: Bool
    """Whether the stalk is thick."""
    var leaf_size: BambooLeafSize
    """The size of the leaves on the bamboo."""

    def __init__(
        out self,
        *,
        ready: Bool = False,
        thick: Bool = False,
        leaf_size: BambooLeafSize = BambooLeafSize.NO_LEAVES,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            ready: Whether the bamboo is ready to grow.
            thick: Whether the stalk is thick.
            leaf_size: The size of the leaves on the bamboo.
        """
        self.ready = ready
        self.thick = thick
        self.leaf_size = leaf_size

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
        var thickness = "thick" if self.thick else "thin"
        return BlockState(
            "minecraft:bamboo",
            Properties()
            .with_byte("age_bit", UInt8(self.ready))
            .with_string("bamboo_leaf_size", String(self.leaf_size))
            .with_string("bamboo_stalk_thickness", thickness),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            (UInt64(1) if self.ready else UInt64(0))
            | (UInt64(1) if self.thick else UInt64(0)) << 1
            | UInt64(self.leaf_size.uint8()) << 2
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Bamboo(
            ready=hash & 0x1 != 0,
            thick=(hash >> 1) & 0x1 != 0,
            leaf_size=BambooLeafSize(Int((hash >> 2) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for ready in [False, True]:
            for thick in [False, True]:
                for leaf_size in bamboo_leaf_sizes():
                    out.append(
                        Bamboo(ready=ready, thick=thick, leaf_size=leaf_size)
                    )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(1, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> BambooModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return BambooModel(thick=self.thick)
