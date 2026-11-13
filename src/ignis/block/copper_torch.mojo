"""`CopperTorch`, ported from Dragonfly `server/block/copper_torch.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, HasLiquidDrops,
EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_state import BlockState, Properties
from .block import UNKNOWN_FACE
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.face import Face, faces
from .hash import HASH_COPPER_TORCH


struct CopperTorch(
    Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser, LightEmitter
):
    """A non-solid block that emits light."""

    comptime BASE_HASH: UInt64 = HASH_COPPER_TORCH
    """Go `hashCopperTorch`."""

    var facing: Face
    """The face the torch is attached to; `UNKNOWN_FACE` stands for standing."""

    def __init__(out self, *, facing: Face = Face.DOWN):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The face the torch is attached to; `UNKNOWN_FACE` stands for standing.
        """
        self.facing = facing

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
        var face: String
        if self.facing == Face.DOWN:
            face = "top"
        elif self.facing == UNKNOWN_FACE:
            face = "unknown"
        else:
            face = String(self.facing)
        return BlockState(
            "minecraft:copper_torch",
            Properties().with_string("torch_facing_direction", face^),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(Int(self.facing))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return CopperTorch(facing=Face(Int(hash & 0x7)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for face in faces():
            if face == Face.UP:
                out.append(CopperTorch(facing=UNKNOWN_FACE))
            else:
                out.append(CopperTorch(facing=face))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        return 14

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
