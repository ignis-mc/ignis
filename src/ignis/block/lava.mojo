"""`Lava`, ported from Dragonfly `server/block/lava.go`.

Go's `world.Liquid` interface (LiquidDepth, SpreadDecay, WithDepth,
LiquidFalling, BlastResistance, LiquidType, Harden) comes with liquids in
world-runtime.

TODO(world-runtime): EntityInside, ScheduledTick, NeighbourUpdateTick,
RandomTick (fire spread), Harden, LavaDamageSource, the `world.Liquid`
methods.
"""

from std.os import abort

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_state import BlockState, Properties
from .hash import HASH_LAVA


struct Lava(Block, Equatable, ImplicitlyCopyable, LightDiffuser, LightEmitter):
    """A light-emitting fluid block that causes fire damage."""

    comptime BASE_HASH: UInt64 = HASH_LAVA
    """Go `hashLava`."""

    var still: Bool
    """Whether the liquid is still, a source block that does not flow."""
    var depth: Int
    """The depth of the liquid, 1 to 8."""
    var falling: Bool
    """Whether the liquid falls down."""

    def __init__(
        out self, *, still: Bool = False, depth: Int = 8, falling: Bool = False
    ):
        """Creates the block; `depth` defaults to 8, a full block.

        Args:
            still: Whether the liquid is still, a source block that does not flow.
            depth: The depth of the liquid, 1 to 8.
            falling: Whether the liquid falls down.
        """
        self.still = still
        self.depth = depth
        self.falling = falling

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
        if self.depth < 1 or self.depth > 8:
            abort("invalid lava depth, must be between 1 and 8")
        var v = Int32(8 - self.depth)
        if self.falling:
            v += 8
        var name = "minecraft:lava" if self.still else "minecraft:flowing_lava"
        return BlockState(name, Properties().with_int("liquid_depth", v))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            (UInt64(1) if self.still else UInt64(0))
            | UInt64(self.depth) << 1
            | (UInt64(1) if self.falling else UInt64(0)) << 9
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Lava(
            still=hash & 0x1 != 0,
            depth=Int((hash >> 1) & 0xFF),
            falling=(hash >> 9) & 0x1 != 0,
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
            (False, False),
            (False, True),
        ]:
            for depth in range(8, 0, -1):
                out.append(Lava(still=flags[0], falling=flags[1], depth=depth))
        return out^

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
        return 2
