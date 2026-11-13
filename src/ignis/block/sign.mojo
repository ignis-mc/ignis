"""`Sign`, ported from Dragonfly `server/block/sign.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `Front` and `Back` `SignText` fields (text, base
colour, glow, owner), SideClosed, Ink, Wax, Activate, EditingFace,
UseOnBlock, NeighbourUpdateTick, DecodeNBT, EncodeNBT, FlammabilityInfo,
FuelInfo, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState, Properties
from .attachment import (
    Attachment,
    attachment_from_uint8,
    standing_attachment,
    wall_attachment,
)
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import directions
from .cube.orientation import Orientation
from .hash import HASH_SIGN
from .wood_type import WoodType, wood_types


struct Sign(Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser):
    """A non-solid block that can display text."""

    comptime BASE_HASH: UInt64 = HASH_SIGN
    """Go `hashSign`."""

    var wood: WoodType
    """The type of wood of the sign."""
    var attach: Attachment
    """How the sign is attached."""
    var waxed: Bool
    """Whether the sign is waxed, which stops it from being edited."""

    def __init__(
        out self,
        *,
        wood: WoodType = WoodType.OAK,
        attach: Attachment = Attachment(),
        waxed: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            wood: The type of wood of the sign.
            attach: How the sign is attached.
            waxed: Whether the sign is waxed, which stops it from being edited.
        """
        self.wood = wood
        self.attach = attach
        self.waxed = waxed

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return self.hash() == other.hash() and self.waxed == other.waxed

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        var wood = String(t"{self.wood}_")
        if self.wood == WoodType.OAK:
            wood = ""
        elif self.wood == WoodType.DARK_OAK:
            wood = "darkoak_"
        if self.attach.hanging():
            return BlockState(
                String(t"minecraft:{wood}wall_sign"),
                Properties().with_int(
                    "facing_direction", Int32(Int(self.attach.facing()) + 2)
                ),
            )
        return BlockState(
            String(t"minecraft:{wood}standing_sign"),
            Properties().with_int(
                "ground_sign_direction", Int32(Int(self.attach.orientation()))
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.wood.uint8()) | UInt64(self.attach.uint8()) << 4

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Sign(
            wood=WoodType(Int(hash & 0xF)),
            attach=attachment_from_uint8(Int((hash >> 4) & 0x1F)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for w in wood_types():
            for d in directions():
                out.append(Sign(wood=w, attach=wall_attachment(d)))
            for o in range(16):
                out.append(
                    Sign(wood=w, attach=standing_attachment(Orientation(o)))
                )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(1, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
