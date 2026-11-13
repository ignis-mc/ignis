"""`Stairs`, ported from Dragonfly `server/block/stairs.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, DeriveState,
calculateCorner, continued, Model, Instrument, FlammabilityInfo, FuelInfo,
SideClosed, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState, Properties
from .break_info import BreakInfo, Breakable, new_break_info
from .cube.direction import Direction
from .hash import HASH_STAIRS, AnyBlock, hash_block, unhash_block
from .register import break_info
from .stairs_corner import StairsCorner, stairs_corners
from .stairs_type import encode_stairs_block, stairs_blocks


struct Stairs(Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser):
    """A block that allows entities to walk up blocks without jumping."""

    comptime BASE_HASH: UInt64 = HASH_STAIRS
    """Go `hashStairs`."""

    var block: AnyBlock
    """The block the stairs are made of."""
    var upside_down: Bool
    """Whether the full side of the stairs is at the top."""
    var facing: Direction
    """The direction the full side of the stairs faces."""
    var corner: StairsCorner
    """The corner the stairs form with the stairs around them."""

    def __init__(
        out self,
        *,
        block: AnyBlock,
        upside_down: Bool = False,
        facing: Direction = Direction.NORTH,
        corner: StairsCorner = StairsCorner.NONE,
    ):
        """Creates the block; `block` is required, the other fields default to Go zero values.

        Args:
            block: The block the stairs are made of.
            upside_down: Whether the full side of the stairs is at the top.
            facing: The direction the full side of the stairs faces.
            corner: The corner the stairs form with the stairs around them.
        """
        self.block = block
        self.upside_down = upside_down
        self.facing = facing
        self.corner = corner

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
            String(t"minecraft:{encode_stairs_block(self.block)}_stairs"),
            Properties()
            .with_string("minecraft:corner", String(self.corner))
            .with_bool("upside_down_bit", self.upside_down)
            .with_int("weirdo_direction", to_stairs_direction(self.facing)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            hash_block(self.block)
            | (UInt64(1) if self.upside_down else UInt64(0)) << 32
            | UInt64(Int(self.facing)) << 33
            | UInt64(self.corner.uint8()) << 35
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Stairs(
            block=unhash_block(hash & 0xFFFFFFFF),
            upside_down=(hash >> 32) & 0x1 != 0,
            facing=Direction(Int((hash >> 33) & 0x3)),
            corner=StairsCorner(Int((hash >> 35) & 0x7)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for i in range(4):
            for upside_down in [True, False]:
                for s in stairs_blocks():
                    for corner in stairs_corners():
                        out.append(
                            Stairs(
                                block=s,
                                upside_down=upside_down,
                                facing=Direction(i),
                                corner=corner,
                            )
                        )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        var info = break_info(self.block.kind, self.block.state).value()
        return new_break_info(
            info.hardness, info.harvestable, info.effective
        ).with_blast_resistance(info.blast_resistance)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0


def to_stairs_direction(v: Direction) -> Int32:
    """Converts a direction to the `weirdo_direction` property (Go
    `toStairsDirection`).

    Args:
        v: The direction the full side faces.

    Returns:
        `3 - v`.
    """
    return Int32(3 - Int(v))
