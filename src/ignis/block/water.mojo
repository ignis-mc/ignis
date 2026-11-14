"""`Water`, ported from Dragonfly `server/block/water.go`.

Go's `world.Liquid` interface (LiquidDepth, SpreadDecay, WithDepth,
LiquidFalling, BlastResistance, LiquidType, Harden) comes with liquids in
world-runtime.

TODO(world-runtime): EntityInside, PistonBreakable, Spread, ScheduledTick,
NeighbourUpdateTick, the `world.Liquid` methods.
"""

from std.os import abort

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .hash import HASH_WATER
from .model.empty import Empty as EmptyModel


struct Water(
    Block, Equatable, ImplicitlyCopyable, LightDiffuser, ModelledBlock
):
    """A natural fluid that generates abundantly in the world."""

    comptime BASE_HASH: UInt64 = HASH_WATER
    """Go `hashWater`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var still: Bool
    """Whether the liquid is still, a source block that does not flow."""
    var depth: Int
    """The depth of the liquid, 1 to 8."""
    var falling: Bool
    """Whether the liquid falls down."""

    def __init__(
        out self, *, still: Bool = False, depth: Int = 8, falling: Bool = False
    ):
        """Creates the block; `depth` defaults to 8, a full block."""
        self.still = still
        self.depth = depth
        self.falling = falling

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.depth < 1 or self.depth > 8:
            abort("invalid water depth, must be between 1 and 8")
        var v = Int32(8 - self.depth)
        if self.falling:
            v += 8
        var name = (
            "minecraft:water" if self.still else "minecraft:flowing_water"
        )
        return BlockState(name, Properties().with_int("liquid_depth", v))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            (UInt64(1) if self.still else UInt64(0))
            | UInt64(self.depth) << 1
            | (UInt64(1) if self.falling else UInt64(0)) << 9
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Water(
            still=hash & 0x1 != 0,
            depth=Int((hash >> 1) & 0xFF),
            falling=(hash >> 9) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for flags in [
            (True, True),
            (True, False),
            (False, False),
            (False, True),
        ]:
            for depth in range(8, 0, -1):
                out.append(Water(still=flags[0], falling=flags[1], depth=depth))
        return out^

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 2

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()
