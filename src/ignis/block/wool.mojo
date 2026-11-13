"""`Wool`, ported from Dragonfly `server/block/wool.go`.

TODO(world-runtime): Instrument, FlammabilityInfo, EncodeItem and the drops.
"""

from ..item.colour import Colour, colours
from ..world.block import Block
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    SHEARS_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_WOOL


struct Wool(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A colourful block that can be obtained by killing or shearing sheep, or crafted using
    four string."""

    comptime BASE_HASH: UInt64 = HASH_WOOL
    """Go `hashWool`."""

    var colour: Colour
    """The colour of the wool."""

    def __init__(out self, *, colour: Colour = Colour.WHITE):
        """Creates the block; omitted fields take Go zero values.

        Args:
            colour: The colour of the wool.
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
        return BlockState(String(t"minecraft:{self.colour}_wool"))

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
        return Wool(colour=Colour(Int(hash & 0xF)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for colour in colours():
            out.append(Wool(colour=colour))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.8, ALWAYS_HARVESTABLE, SHEARS_EFFECTIVE)
