"""`WoodTrapdoor`, ported from Dragonfly `server/block/wood_trapdoor.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): UseOnBlock, Activate, SideClosed, Model,
FlammabilityInfo, FuelInfo, EncodeItem and the drops.
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
from .hash import HASH_WOOD_TRAPDOOR
from .wood_type import WoodType, wood_types


struct WoodTrapdoor(
    Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser
):
    """A wooden trapdoor, opened and closed by players."""

    comptime BASE_HASH: UInt64 = HASH_WOOD_TRAPDOOR
    """Go `hashWoodTrapdoor`."""

    var wood: WoodType
    """The type of wood."""
    var facing: Direction
    """The direction the trapdoor faces."""
    var open: Bool
    """Whether the trapdoor is open."""
    var top: Bool
    """Whether the trapdoor is in the top half of the block."""

    def __init__(
        out self,
        *,
        wood: WoodType = WoodType.OAK,
        facing: Direction = Direction.NORTH,
        open: Bool = False,
        top: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            wood: The type of wood.
            facing: The direction the trapdoor faces.
            open: Whether the trapdoor is open.
            top: Whether the trapdoor is in the top half of the block.
        """
        self.wood = wood
        self.facing = facing
        self.open = open
        self.top = top

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
        var name = String(t"minecraft:{self.wood}_trapdoor")
        if self.wood == WoodType.OAK:
            name = "minecraft:trapdoor"
        return BlockState(
            name^,
            Properties()
            .with_int("direction", Int32(3 - Int(self.facing)))
            .with_bool("open_bit", self.open)
            .with_bool("upside_down_bit", self.top),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.wood.uint8())
            | UInt64(Int(self.facing)) << 4
            | (UInt64(1) if self.open else UInt64(0)) << 6
            | (UInt64(1) if self.top else UInt64(0)) << 7
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return WoodTrapdoor(
            wood=WoodType(Int(hash & 0xF)),
            facing=Direction(Int((hash >> 4) & 0x3)),
            open=(hash >> 6) & 0x1 != 0,
            top=(hash >> 7) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for wood in wood_types():
            for facing in directions():
                for open in [False, True]:
                    for top in [False, True]:
                        out.append(
                            WoodTrapdoor(
                                wood=wood, facing=facing, open=open, top=top
                            )
                        )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(3, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
