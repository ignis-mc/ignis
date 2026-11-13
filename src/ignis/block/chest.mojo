"""`Chest`, ported from Dragonfly `server/block/chest.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the inventory, pairing (paired, pairX, pairZ, pairInv)
and viewer fields, NewChest, Inventory, WithName, SideClosed, AddViewer,
RemoveViewer, Activate, UseOnBlock, open/close, Paired, pair, unpair,
DecodeNBT, EncodeNBT, the break handler, FlammabilityInfo, FuelInfo,
EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_CHEST


struct Chest(Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser):
    """A container block which may be used to store items."""

    comptime BASE_HASH: UInt64 = HASH_CHEST
    """Go `hashChest`."""

    var facing: Direction
    """The direction the chest faces."""
    var custom_name: String
    """The custom name of the block, shown in its window."""

    def __init__(
        out self,
        *,
        facing: Direction = Direction.NORTH,
        custom_name: String = String(),
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The direction the chest faces.
            custom_name: The custom name of the block, shown in its window.
        """
        self.facing = facing
        self.custom_name = custom_name

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return (
            self.hash() == other.hash()
            and self.custom_name == other.custom_name
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState(
            "minecraft:chest",
            Properties().with_string(
                "minecraft:cardinal_direction", String(self.facing)
            ),
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
        return Chest(facing=Direction(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for facing in directions():
            out.append(Chest(facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(2.5, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
