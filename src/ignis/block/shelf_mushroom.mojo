"""`ShelfMushroom`, ported from Dragonfly `server/block/shelf_mushroom.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, BoneMeal, Model,
CompostChance, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_SHELF_MUSHROOM


struct ShelfMushroom(
    Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser
):
    """A mushroom that grows on the side of logs."""

    comptime BASE_HASH: UInt64 = HASH_SHELF_MUSHROOM
    """Go `hashShelfMushroom`."""

    var facing: Direction
    """The direction the mushroom faces, away from the block it is attached to."""
    var large: Bool
    """Whether the mushroom has grown to its large stage."""

    def __init__(
        out self, *, facing: Direction = Direction.NORTH, large: Bool = False
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The direction the mushroom faces, away from the block it is attached to.
            large: Whether the mushroom has grown to its large stage.
        """
        self.facing = facing
        self.large = large

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
        return BlockState(
            "minecraft:shelf_mushroom",
            Properties()
            .with_string("minecraft:cardinal_direction", String(self.facing))
            .with_int("growth", Int32(1) if self.large else Int32(0)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.large else UInt64(0)) << 2
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return ShelfMushroom(
            facing=Direction(Int(hash & 0x3)), large=(hash >> 2) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for d in directions():
            out.append(ShelfMushroom(facing=d))
            out.append(ShelfMushroom(facing=d, large=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
