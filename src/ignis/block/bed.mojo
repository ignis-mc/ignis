"""`Bed`, ported from Dragonfly `server/block/bed.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `Sleeper` entity handle, Model, SideClosed,
UseOnBlock, Activate, EntityLand, bounce, NeighbourUpdateTick, head, the
break handler waking the sleeper, EncodeItem and the drops, DecodeNBT,
EncodeNBT.
"""

from ..item.colour import Colour
from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState, Properties
from .block import horizontal_direction
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_BED


struct Bed(Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser):
    """A block that allows players to sleep to set their spawn point and skip the night.
    """

    comptime BASE_HASH: UInt64 = HASH_BED
    """Go `hashBed`."""

    var colour: Colour
    """The colour of the bed, kept in NBT."""
    var facing: Direction
    """The direction the head of the bed faces."""
    var head: Bool
    """Whether this is the head of the bed."""
    var occupied: Bool
    """Whether someone sleeps in the bed."""

    def __init__(
        out self,
        *,
        colour: Colour = Colour.WHITE,
        facing: Direction = Direction.NORTH,
        head: Bool = False,
        occupied: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            colour: The colour of the bed, kept in NBT.
            facing: The direction the head of the bed faces.
            head: Whether this is the head of the bed.
            occupied: Whether someone sleeps in the bed.
        """
        self.colour = colour
        self.facing = facing
        self.head = head
        self.occupied = occupied

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return self.hash() == other.hash() and self.colour == other.colour

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState(
            "minecraft:bed",
            Properties()
            .with_int(
                "direction", Int32(Int(horizontal_direction(self.facing)))
            )
            .with_byte("occupied_bit", UInt8(self.occupied))
            .with_byte("head_piece_bit", UInt8(self.head)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.head else UInt64(0)) << 2
            | (UInt64(1) if self.occupied else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Bed(
            facing=Direction(Int(hash & 0x3)),
            head=(hash >> 2) & 0x1 != 0,
            occupied=(hash >> 3) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for d in directions():
            for head in [False, True]:
                for occupied in [False, True]:
                    out.append(Bed(facing=d, head=head, occupied=occupied))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.2, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
