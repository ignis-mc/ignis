"""`Hopper`, ported from Dragonfly `server/block/hopper.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the inventory, viewer fields, NewHopper, Model, Inventory,
WithName, AddViewer, RemoveViewer, Activate, UseOnBlock, Tick, insertItem,
extractItem, RedstoneUpdate, the break handler and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_int32, get_string
from ..world.block import Block, LightDiffuser, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.face import Face, faces
from .hash import HASH_HOPPER
from .model.hopper import Hopper as HopperModel
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct Hopper(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    ModelledBlock,
    NBTer,
):
    """A block used to collect item entities directly above it, as well as to transfer items into
    and out of other containers."""

    comptime BASE_HASH: UInt64 = HASH_HOPPER
    """Go `hashHopper`."""
    comptime ModelType = HopperModel
    """The model type (Go `Model`)."""

    var facing: Face
    """The direction the hopper faces."""
    var powered: Bool
    """Whether the hopper is powered by redstone, which stops it transferring items."""
    var custom_name: String
    """The custom name of the block, shown in its window."""
    var transfer_cooldown: Int
    """The ticks until the hopper may transfer items again."""
    var collect_cooldown: Int
    """The ticks until the hopper may collect items again."""

    def __init__(
        out self,
        *,
        facing: Face = Face.DOWN,
        powered: Bool = False,
        custom_name: String = String(),
        transfer_cooldown: Int = 0,
        collect_cooldown: Int = 0,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.powered = powered
        self.custom_name = custom_name
        self.transfer_cooldown = transfer_cooldown
        self.collect_cooldown = collect_cooldown

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return (
            self.hash() == other.hash()
            and self.custom_name == other.custom_name
            and self.transfer_cooldown == other.transfer_cooldown
            and self.collect_cooldown == other.collect_cooldown
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:hopper",
            Properties()
            .with_int("facing_direction", Int32(Int(self.facing)))
            .with_bool("toggle_bit", self.powered),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.powered else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Hopper(
            facing=Face(Int(hash & 0x7)), powered=(hash >> 3) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for f in faces():
            out.append(Hopper(facing=f))
            out.append(Hopper(facing=f, powered=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            3, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(4.8)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> HopperModel:
        """Returns the model of the block (Go `Model`)."""
        return HopperModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:hopper", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        # TODO(world-runtime): the inventory; Go writes an empty one as an
        # empty list.
        _ = tag.put_list(root, "Items")
        _ = tag.put_int(root, "TransferCooldown", Int32(self.transfer_cooldown))
        _ = tag.put_string(root, "id", "Hopper")
        if self.custom_name.byte_length() != 0:
            _ = tag.put_string(root, "CustomName", self.custom_name)

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        # TODO(world-runtime): the inventory.
        return Self(
            facing=self.facing,
            powered=self.powered,
            custom_name=get_string(tag, root, "CustomName"),
            transfer_cooldown=Int(get_int32(tag, root, "TransferCooldown")),
        )

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
