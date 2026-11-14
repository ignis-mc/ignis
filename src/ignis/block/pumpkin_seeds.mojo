"""`PumpkinSeeds`, ported from Dragonfly `server/block/pumpkin_seeds.go`.

TODO(world-runtime): the `crop` helpers (NeighbourUpdateTick,
HasLiquidDrops, CalculateGrowthChance), GrowthStage, SameCrop, RandomTick,
BoneMeal, UseOnBlock, CompostChance, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.face import Face
from .hash import HASH_PUMPKIN_SEEDS
from .model.empty import Empty as EmptyModel


struct PumpkinSeeds(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A crop that grows pumpkin blocks."""

    comptime BASE_HASH: UInt64 = HASH_PUMPKIN_SEEDS
    """Go `hashPumpkinSeeds`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var growth: Int
    """The growth stage of the crop, 0 to 7 (Go `crop.Growth`)."""
    var direction: Face
    """The direction from the stem to the fruit."""

    def __init__(out self, *, growth: Int = 0, direction: Face = Face.DOWN):
        """Creates the block; omitted fields take Go zero values.

        Args:
            growth: The growth stage of the crop, 0 to 7 (Go `crop.Growth`).
            direction: The direction from the stem to the fruit.
        """
        self.growth = growth
        self.direction = direction

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
            "minecraft:pumpkin_stem",
            Properties()
            .with_int("facing_direction", Int32(Int(self.direction)))
            .with_int("growth", Int32(self.growth)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.growth) | UInt64(Int(self.direction)) << 8

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return PumpkinSeeds(
            growth=Int(hash & 0xFF), direction=Face(Int((hash >> 8) & 0x7))
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for i in range(8):
            for j in range(6):
                out.append(PumpkinSeeds(growth=i, direction=Face(j)))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

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
