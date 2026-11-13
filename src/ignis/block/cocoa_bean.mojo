"""`CocoaBean`, ported from Dragonfly `server/block/cocoa_bean.go`.

TODO(world-runtime): BoneMeal, HasLiquidDrops, NeighbourUpdateTick,
UseOnBlock, RandomTick, Model, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .block import horizontal_direction
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_COCOA_BEAN
from .model.cocoa_bean import CocoaBean as CocoaBeanModel


struct CocoaBean(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A crop block found in jungle biomes."""

    comptime BASE_HASH: UInt64 = HASH_COCOA_BEAN
    """Go `hashCocoaBean`."""
    comptime ModelType = CocoaBeanModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction from the cocoa bean to the log."""
    var age: Int
    """The stage of growth, 0 to 2; 2 is fully grown."""

    def __init__(
        out self, *, facing: Direction = Direction.NORTH, age: Int = 0
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The direction from the cocoa bean to the log.
            age: The stage of growth, 0 to 2; 2 is fully grown.
        """
        self.facing = facing
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
            "minecraft:cocoa",
            Properties()
            .with_int("age", Int32(self.age))
            .with_int(
                "direction", Int32(Int(horizontal_direction(self.facing)))
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(Int(self.facing)) | UInt64(self.age) << 2

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return CocoaBean(
            facing=Direction(Int(hash & 0x3)), age=Int((hash >> 2) & 0xFF)
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for facing in directions():
            for age in range(3):
                out.append(CocoaBean(facing=facing, age=age))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            0.2, ALWAYS_HARVESTABLE, AXE_EFFECTIVE
        ).with_blast_resistance(3)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> CocoaBeanModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return CocoaBeanModel(facing=self.facing, age=self.age)
