"""`Skull`, ported from Dragonfly `server/block/skull.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): Helmet, DefencePoints, Toughness, KnockBackResistance,
SideClosed, UseOnBlock, Model, DecodeNBT, EncodeNBT, EncodeItem and the
drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .attachment import (
    Attachment,
    attachment_from_uint8,
    standing_attachment,
    wall_attachment,
)
from .block import UNKNOWN_DIRECTION
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import directions
from .cube.orientation import Orientation
from .hash import HASH_SKULL
from .model.skull import Skull as SkullModel
from .skull_type import SkullType, skull_types


struct Skull(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A decorative block that can be worn as a helmet."""

    comptime BASE_HASH: UInt64 = HASH_SKULL
    """Go `hashSkull`."""
    comptime ModelType = SkullModel
    """The model type (Go `Model`)."""

    var type: SkullType
    """The type of the skull."""
    var attach: Attachment
    """How the skull is attached; only standing or wall attachments are stored."""

    def __init__(
        out self,
        *,
        type: SkullType = SkullType.SKELETON,
        attach: Attachment = Attachment(),
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            type: The type of the skull.
            attach: How the skull is attached; only standing or wall attachments are stored.
        """
        self.type = type
        self.attach = attach

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
        var facing = Int32(1)
        if self.attach.hanging():
            facing = 0
            if self.attach.facing() != UNKNOWN_DIRECTION:
                facing = Int32(Int(self.attach.facing())) + 2
        return BlockState(
            String(t"minecraft:{self.type}"),
            Properties().with_int("facing_direction", facing),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.type.uint8()) | UInt64(self.attach.face_uint8()) << 3

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Skull(
            type=SkullType(Int(hash & 0x7)),
            attach=attachment_from_uint8(Int((hash >> 3) & 0xF)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for t in skull_types():
            for d in directions():
                out.append(Skull(type=t, attach=wall_attachment(d)))
            out.append(Skull(type=t, attach=wall_attachment(UNKNOWN_DIRECTION)))
            out.append(
                Skull(type=t, attach=standing_attachment(Orientation(0)))
            )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(1, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> SkullModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SkullModel(
            direction=self.attach.facing().face(), hanging=self.attach.hanging()
        )
