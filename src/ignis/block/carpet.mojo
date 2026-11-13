"""`Carpet`, ported from Dragonfly `server/block/carpet.go`.

Go's `sourceWaterDisplacer` makes carpets a `LiquidDisplacer`; that trait
comes with liquids.

TODO(world-runtime): SideClosed, HasLiquidDrops, NeighbourUpdateTick,
UseOnBlock, FlammabilityInfo, EncodeItem and the drops.
"""

from ..item.colour import Colour, colours
from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_CARPET


struct Carpet(Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser):
    """A colourful decorative block that can be placed on top of any block."""

    comptime BASE_HASH: UInt64 = HASH_CARPET
    """Go `hashCarpet`."""

    var colour: Colour
    """The colour of the carpet."""

    def __init__(out self, *, colour: Colour = Colour.WHITE):
        """Creates the block; omitted fields take Go zero values.

        Args:
            colour: The colour of the carpet.
        """
        self.colour = colour

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
        return BlockState(String(t"minecraft:{self.colour}_carpet"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.colour.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Carpet(colour=Colour(Int(hash & 0xF)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for colour in colours():
            out.append(Carpet(colour=colour))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.1, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
