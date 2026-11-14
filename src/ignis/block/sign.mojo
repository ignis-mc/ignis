"""`Sign`, ported from Dragonfly `server/block/sign.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `Front`, `Back` `SignText` fields (text, base colour,
glow, owner), SideClosed, Ink, Wax, Activate, EditingFace, UseOnBlock,
NeighbourUpdateTick, FlammabilityInfo and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..item.item import MaxCounter
from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block, LightDiffuser, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
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
from .model.empty import Empty as EmptyModel
from .wood_type import WoodType, wood_types
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct Sign(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    MaxCounter,
    ModelledBlock,
    NBTer,
):
    """A non-solid block that can display text."""

    comptime BASE_HASH: UInt64 = HASH_SIGN
    """Go `hashSign`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

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
        """Creates the block; omitted fields take Go zero values."""
        self.wood = wood
        self.attach = attach
        self.waxed = waxed

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash() and self.waxed == other.waxed

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
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
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.wood.uint8()) | UInt64(self.attach.uint8()) << 4

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Sign(
            wood=WoodType(Int(hash & 0xF)),
            attach=attachment_from_uint8(Int((hash >> 4) & 0x1F)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
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
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(1, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.wood}_sign"), 0)

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 16

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`); none for nether wood."""
        if not self.wood.flammable():
            return FuelInfo()
        return FuelInfo(10000)

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the NBT (Go `EncodeNBT`)."""
        _ = tag.put_string(root, "id", "Sign")
        _ = tag.put_byte(root, "IsWaxed", UInt8(1) if self.waxed else 0)
        # The sign texts are not ported: both sides are Go's zero SignText,
        # whose colour nbtconv writes as opaque black.
        for side in ["FrontText", "BackText"]:
            var c = tag.put_compound(root, side)
            _ = tag.put_int(c, "SignTextColor", -0x1000000)
            _ = tag.put_byte(c, "IgnoreLighting", 0)
            _ = tag.put_string(c, "Text", "")
            _ = tag.put_string(c, "TextOwner", "")

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Decodes the NBT (Go `DecodeNBT`); only `IsWaxed` is kept."""
        var s = self
        s.waxed = False
        if case .Some(t) = tag.get(root, "IsWaxed"):
            s.waxed = tag.as_byte(t) != 0
        return s

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in wood_types():
            out.append(Sign(wood=v))
        return out^

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
