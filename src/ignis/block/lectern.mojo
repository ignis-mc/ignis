"""`Lectern`, ported from Dragonfly `server/block/lectern.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `Book item.Stack` field, Model, SideClosed,
UseOnBlock, Activate, Punch, TurnPage, EncodeNBT, DecodeNBT,
FlammabilityInfo, FuelInfo, EncodeItem and the drops (the book).
"""

from ..world.block import Block
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_LECTERN


struct Lectern(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A librarian's job site block found in villages, used to hold books for multiple players to
    read in multiplayer."""

    comptime BASE_HASH: UInt64 = HASH_LECTERN
    """Go `hashLectern`."""

    var facing: Direction
    """The direction the lectern faces."""
    var page: Int
    """The page the book on the lectern is opened to."""

    def __init__(
        out self, *, facing: Direction = Direction.NORTH, page: Int = 0
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The direction the lectern faces.
            page: The page the book on the lectern is opened to.
        """
        self.facing = facing
        self.page = page

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return self.hash() == other.hash() and self.page == other.page

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState(
            "minecraft:lectern",
            Properties()
            .with_string("minecraft:cardinal_direction", String(self.facing))
            .with_byte("powered_bit", 0),
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
        return Lectern(facing=Direction(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for facing in directions():
            out.append(Lectern(facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(2.5, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)
