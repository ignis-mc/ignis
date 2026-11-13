"""`Beacon`, ported from Dragonfly `server/block/beacon.go`.

Go's `sourceWaterDisplacer` makes beacons a `LiquidDisplacer`; that trait
comes with liquids.

TODO(world-runtime): the `Primary` and `Secondary` `effect.LastingType`
fields, DecodeNBT, EncodeNBT, SideClosed, Activate, Level, Tick,
recalculateLevel, obstructed, broadcastBeaconEffects, EncodeItem and the
drops.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_BEACON
from .model.solid import Solid as SolidModel


struct Beacon(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    LightEmitter,
    ModelledBlock,
):
    """A block that projects a light beam skyward, and can provide status effects such as Speed,
    Jump Boost, Haste, Regeneration, Resistance, or Strength to nearby players.
    """

    comptime BASE_HASH: UInt64 = HASH_BEACON
    """Go `hashBeacon`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var level: Int
    """The amount of pyramid levels the beacon is on, 0 to 4."""

    def __init__(out self, *, level: Int = 0):
        """Creates the block; omitted fields take Go zero values.

        Args:
            level: The amount of pyramid levels the beacon is on, 0 to 4.
        """
        self.level = level

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return self.hash() == other.hash() and self.level == other.level

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState("minecraft:beacon")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Beacon()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Beacon()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(3, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        return 15

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()
