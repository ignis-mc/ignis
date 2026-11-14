"""`Banner`, ported from Dragonfly `server/block/banner.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, SideClosed, DecodeNBT,
EncodeNBT, FlammabilityInfo and the drops.
"""

from ..item.colour import Colour, colours
from ..item.item import MaxCounter
from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
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
from .model.empty import Empty as EmptyModel


struct Banner(
    Block,
    Breakable,
    Copyable,
    Equatable,
    Fuel,
    Item,
    LightDiffuser,
    MaxCounter,
    ModelledBlock,
):
    """A tall decorative block that can be customised."""

    comptime BASE_HASH: UInt64 = HASH_BANNER
    """Go `hashBanner`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

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

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return EmptyModel()

    def max_count(self) -> Int:
        """Returns the maximum stack count (Go `MaxCount`)."""
        return 16

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        # Go invertColour.
        return EncodedItem(
            "minecraft:banner", ~Int16(self.colour.uint8()) & 0xF
        )

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for c in colours():
            out.append(Self(colour=c))
        return out^
