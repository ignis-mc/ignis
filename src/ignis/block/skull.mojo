"""`Skull`, ported from Dragonfly `server/block/skull.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): SideClosed, UseOnBlock, Model and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..item.armour import HelmetType
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
from .block import UNKNOWN_DIRECTION
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    new_break_info,
)
from .cube.direction import directions
from .cube.orientation import Orientation, orientation_from_yaw
from .hash import HASH_SKULL
from .model.skull import Skull as SkullModel
from .skull_type import SkullType, skull_types


struct Skull(
    Block,
    Breakable,
    Equatable,
    HelmetType,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    NBTer,
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
        """Creates the block; omitted fields take Go zero values."""
        self.type = type
        self.attach = attach

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
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
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.type.uint8()) | UInt64(self.attach.face_uint8()) << 3

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Skull(
            type=SkullType(Int(hash & 0x7)),
            attach=attachment_from_uint8(Int((hash >> 3) & 0xF)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
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
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(1, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> SkullModel:
        """Returns the model of the block (Go `Model`)."""
        return SkullModel(
            direction=self.attach.facing().face(), hanging=self.attach.hanging()
        )

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.type}"), 0)

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the NBT (Go `EncodeNBT`)."""
        _ = tag.put_string(root, "id", "Skull")
        _ = tag.put_byte(root, "SkullType", 255)
        _ = tag.put_float(
            root, "Rotation", Float32(self.attach.orientation().yaw())
        )

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Decodes the NBT (Go `DecodeNBT`)."""
        var s = self
        if case .Some(t) = tag.get(root, "SkullType"):
            var v = tag.as_byte(t)
            if v != 255:
                s.type = SkullType(Int(v))
        var yaw = Float64(0)
        if case .Some(t) = tag.get(root, "Rotation"):
            yaw = Float64(tag.as_float(t))
        # Go sets the orientation of any attachment, as here.
        s.attach._o = orientation_from_yaw(yaw)
        return s

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in skull_types():
            out.append(Skull(type=v))
        return out^

    def helmet(self) -> Bool:
        """Reports whether the block is worn as a helmet (Go `Helmet`)."""
        return True

    def defence_points(self) -> Float64:
        """Returns the defence points (Go `DefencePoints`): none."""
        return 0

    def toughness(self) -> Float64:
        """Returns the toughness (Go `Toughness`): none."""
        return 0

    def knock_back_resistance(self) -> Float64:
        """Returns the knock-back resistance (Go `KnockBackResistance`)."""
        return 0
