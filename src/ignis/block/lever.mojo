"""`Lever`, ported from Dragonfly `server/block/lever.go`.

Go's `flowingWaterDisplacer` comes with liquids.

TODO(world-runtime): Activate, UseOnBlock, NeighbourUpdateTick, HasLiquidDrops,
SideClosed, RedstoneSource, RedstonePower, RedstoneStrongPower and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction
from .cube.face import Face, faces
from .hash import HASH_LEVER
from .model.empty import Empty as EmptyModel


struct Lever(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """A non-solid block that can provide switchable redstone power."""

    comptime BASE_HASH: UInt64 = HASH_LEVER
    """Go `hashLever`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var powered: Bool
    """Whether the lever is switched on."""
    var facing: Face
    """The face of the block the lever is attached to."""
    var direction: Direction
    """The direction the lever points when on a floor or ceiling."""

    def __init__(
        out self,
        *,
        powered: Bool = False,
        facing: Face = Face.DOWN,
        direction: Direction = Direction.NORTH,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.powered = powered
        self.facing = facing
        self.direction = direction

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var direction = String(self.facing)
        if self.facing == Face.DOWN or self.facing == Face.UP:
            var axis = "east_west"
            if self.direction == Direction.NORTH:
                axis = "north_south"
            direction += "_" + axis
        return BlockState(
            "minecraft:lever",
            Properties()
            .with_bool("open_bit", self.powered)
            .with_string("lever_direction", direction^),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            (UInt64(1) if self.powered else UInt64(0))
            | UInt64(Int(self.facing)) << 1
            | UInt64(Int(self.direction)) << 4
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Lever(
            powered=hash & 0x1 != 0,
            facing=Face(Int((hash >> 1) & 0x7)),
            direction=Direction(Int((hash >> 4) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for facing in faces():
            out.append(Lever(facing=facing, direction=Direction.NORTH))
            out.append(
                Lever(facing=facing, direction=Direction.NORTH, powered=True)
            )
            if facing == Face.DOWN or facing == Face.UP:
                out.append(Lever(facing=facing, direction=Direction.WEST))
                out.append(
                    Lever(facing=facing, direction=Direction.WEST, powered=True)
                )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.5, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:lever", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
