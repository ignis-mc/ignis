"""`Banner`, ported from Dragonfly `server/block/banner.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, SideClosed, DecodeNBT,
EncodeNBT, FlammabilityInfo, FuelInfo, EncodeItem and the drops.
"""

from ..item.colour import Colour
from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState, Properties
from .attachment import (
    Attachment,
    attachment_from_uint8,
    standing_attachment,
    wall_attachment,
)
from .banner_pattern_layer import BannerPatternLayer
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import directions
from .cube.orientation import Orientation
from .hash import HASH_BANNER


struct Banner(Block, Breakable, Copyable, Equatable, LightDiffuser):
    """A tall decorative block that can be customised."""

    comptime BASE_HASH: UInt64 = HASH_BANNER
    """Go `hashBanner`."""

    var colour: Colour
    """The colour of the banner."""
    var attach: Attachment
    """How the banner is attached."""
    var patterns: List[BannerPatternLayer]
    """The layers of patterns on the banner."""
    var illager: Bool
    """Whether the banner is an illager banner."""

    def __init__(
        out self,
        *,
        colour: Colour = Colour.WHITE,
        attach: Attachment = Attachment(),
        var patterns: List[BannerPatternLayer] = List[BannerPatternLayer](),
        illager: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            colour: The colour of the banner.
            attach: How the banner is attached.
            patterns: The layers of patterns on the banner.
            illager: Whether the banner is an illager banner.
        """
        self.colour = colour
        self.attach = attach
        self.patterns = patterns^
        self.illager = illager

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return (
            self.hash() == other.hash()
            and self.colour == other.colour
            and self.patterns == other.patterns
            and self.illager == other.illager
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        if self.attach.hanging():
            return BlockState(
                "minecraft:wall_banner",
                Properties().with_int(
                    "facing_direction", Int32(Int(self.attach.facing()) + 2)
                ),
            )
        return BlockState(
            "minecraft:standing_banner",
            Properties().with_int(
                "ground_sign_direction", Int32(Int(self.attach.orientation()))
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.attach.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Banner(attach=attachment_from_uint8(Int(hash & 0x1F)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for d in directions():
            out.append(Banner(attach=wall_attachment(d)))
        for o in range(16):
            out.append(Banner(attach=standing_attachment(Orientation(o))))
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
