"""`NetherBricks`, ported from Dragonfly `server/block/nether_bricks.go`.

TODO(world-runtime): EncodeItem, SmeltInfo and the `oneOf` drops.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_NETHER_BRICKS
from .nether_bricks_type import NetherBricksType, nether_bricks_types


struct NetherBricks(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A block made from four nether bricks."""

    comptime BASE_HASH: UInt64 = HASH_NETHER_BRICKS
    """Go `hashNetherBricks`."""

    var type: NetherBricksType
    """The type of nether bricks."""

    def __init__(out self, *, type: NetherBricksType = NetherBricksType.NORMAL):
        """Creates the block; omitted fields take Go zero values.

        Args:
            type: The type of nether bricks.
        """
        self.type = type

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
        return BlockState(String(t"minecraft:{self.type}"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return NetherBricks(type=NetherBricksType(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for type in nether_bricks_types():
            out.append(NetherBricks(type=type))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            2, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)
