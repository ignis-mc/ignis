"""`Grindstone`, ported from Dragonfly `server/block/grindstone.go`.

TODO(world-runtime): Model, SideClosed, Activate, UseOnBlock,
NeighbourUpdateTick, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .block import horizontal_direction
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.axis import Axis
from .cube.direction import Direction, directions
from .grindstone_attachment import GrindstoneAttachment, grindstone_attachments
from .hash import HASH_GRINDSTONE
from .model.grindstone import Grindstone as GrindstoneModel


struct Grindstone(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A block that repairs items and tools as well as removing enchantments from them.
    """

    comptime BASE_HASH: UInt64 = HASH_GRINDSTONE
    """Go `hashGrindstone`."""
    comptime ModelType = GrindstoneModel
    """The model type (Go `Model`)."""

    var attach: GrindstoneAttachment
    """How the grindstone is attached."""
    var facing: Direction
    """The direction the grindstone faces."""

    def __init__(
        out self,
        *,
        attach: GrindstoneAttachment = GrindstoneAttachment.STANDING,
        facing: Direction = Direction.NORTH,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            attach: How the grindstone is attached.
            facing: The direction the grindstone faces.
        """
        self.attach = attach
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
        return BlockState(
            "minecraft:grindstone",
            Properties()
            .with_string("attachment", String(self.attach))
            .with_int(
                "direction", Int32(Int(horizontal_direction(self.facing)))
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.attach.uint8()) | UInt64(Int(self.facing)) << 2

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Grindstone(
            attach=GrindstoneAttachment(Int(hash & 0x3)),
            facing=Direction(Int((hash >> 2) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for attach in grindstone_attachments():
            for facing in directions():
                out.append(Grindstone(attach=attach, facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            2, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> GrindstoneModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        var axis = Axis.Y
        if self.attach == GrindstoneAttachment.WALL:
            axis = self.facing.face().axis()
        return GrindstoneModel(axis=axis)
