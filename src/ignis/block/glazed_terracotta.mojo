"""`GlazedTerracotta`, ported from Dragonfly
`server/block/glazed_terracotta.go`.

TODO(world-runtime): UseOnBlock, EncodeItem and the drops.
"""

from ..item.colour import Colour, colours
from ..world.block import Block
from ..world.block_state import BlockState, Properties
from .block import UNKNOWN_DIRECTION
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_GLAZED_TERRACOTTA


struct GlazedTerracotta(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A vibrant solid block that comes in the 16 regular dye colours."""

    comptime BASE_HASH: UInt64 = HASH_GLAZED_TERRACOTTA
    """Go `hashGlazedTerracotta`."""

    var colour: Colour
    """The colour of the glazed terracotta."""
    var facing: Direction
    """The direction the top of the texture faces; `UNKNOWN_DIRECTION` encodes as 0."""

    def __init__(
        out self,
        *,
        colour: Colour = Colour.WHITE,
        facing: Direction = Direction.NORTH,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            colour: The colour of the glazed terracotta.
            facing: The direction the top of the texture faces; `UNKNOWN_DIRECTION` encodes as 0.
        """
        self.colour = colour
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
        var facing = Int32(0)
        if self.facing != UNKNOWN_DIRECTION:
            facing = Int32(2 + Int(self.facing))
        return BlockState(
            String(
                t"minecraft:{self.colour.silver_string()}_glazed_terracotta"
            ),
            Properties().with_int("facing_direction", facing),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.colour.uint8()) | UInt64(Int(self.facing)) << 4

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return GlazedTerracotta(
            colour=Colour(Int(hash & 0xF)),
            facing=Direction(Int((hash >> 4) & 0x7)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        var dirs = directions()
        dirs.append(UNKNOWN_DIRECTION)
        for d in dirs:
            for c in colours():
                out.append(GlazedTerracotta(colour=c, facing=d))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(1.4, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)
