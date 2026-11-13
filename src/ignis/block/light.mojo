"""`Light`, ported from Dragonfly `server/block/light.go`.

Go's `replaceable` and `flowingWaterDisplacer` helpers come with `world.Tx`
and liquids.

TODO(world-runtime): SideClosed, EncodeItem.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from .hash import HASH_LIGHT
from .model.empty import Empty as EmptyModel


struct Light(
    Block,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    LightEmitter,
    ModelledBlock,
):
    """An invisible block that can produce any light level."""

    comptime BASE_HASH: UInt64 = HASH_LIGHT
    """Go `hashLight`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var level: Int
    """The light level the block emits, 0 to 15."""

    def __init__(out self, *, level: Int = 0):
        """Creates the block; omitted fields take Go zero values.

        Args:
            level: The light level the block emits, 0 to 15.
        """
        self.level = level

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
        return BlockState(String(t"minecraft:light_block_{self.level}"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.level)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Light(level=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for level in range(16):
            out.append(Light(level=level))
        return out^

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        return UInt8(self.level)

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
