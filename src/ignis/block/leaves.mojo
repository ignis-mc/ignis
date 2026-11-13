"""`Leaves`, ported from Dragonfly `server/block/leaves.go`.

Go's `sourceWaterDisplacer` makes leaves a `LiquidDisplacer`; that trait
comes with liquids.

TODO(world-runtime): UseOnBlock, RandomTick (with findLog),
NeighbourUpdateTick, FlammabilityInfo, CompostChance, SideClosed, the drops
(saplings, sticks, apples).
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    TOOL_TYPE_HOE,
    TOOL_TYPE_SHEARS,
    BreakInfo,
    Breakable,
    ToolFilter,
    new_break_info,
)
from .hash import HASH_LEAVES
from .leaves_type import LeavesType, leaves_types
from .model.leaves import Leaves as LeavesModel


struct Leaves(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """Blocks that grow as part of trees which mainly drop saplings and sticks.
    """

    comptime BASE_HASH: UInt64 = HASH_LEAVES
    """Go `hashLeaves`."""
    comptime ModelType = LeavesModel
    """The model type (Go `Model`)."""

    var type: LeavesType
    """The type of leaves."""
    var persistent: Bool
    """Whether the leaves were placed by a player and never decay."""
    var should_update: Bool
    """Whether the leaves should check for logs on the next random tick."""

    def __init__(
        out self,
        *,
        type: LeavesType = LeavesType.OAK,
        persistent: Bool = False,
        should_update: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            type: The type of leaves.
            persistent: Whether the leaves were placed by a player and never decay.
            should_update: Whether the leaves should check for logs on the next random tick.
        """
        self.type = type
        self.persistent = persistent
        self.should_update = should_update

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
            Properties()
            .with_bool("persistent_bit", self.persistent)
            .with_bool("update_bit", self.should_update),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.type.uint8())
            | (UInt64(1) if self.persistent else UInt64(0)) << 4
            | (UInt64(1) if self.should_update else UInt64(0)) << 5
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Leaves(
            type=LeavesType(Int(hash & 0xF)),
            persistent=(hash >> 4) & 0x1 != 0,
            should_update=(hash >> 5) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for flags in [
            (True, True),
            (True, False),
            (False, True),
            (False, False),
        ]:
            for t in leaves_types():
                out.append(
                    Leaves(type=t, persistent=flags[0], should_update=flags[1])
                )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            0.2, ALWAYS_HARVESTABLE, ToolFilter(TOOL_TYPE_SHEARS, TOOL_TYPE_HOE)
        )

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 1

    def model(self) -> LeavesModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return LeavesModel()
