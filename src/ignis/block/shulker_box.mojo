"""`ShulkerBox`, ported from Dragonfly `server/block/shulker_box.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the inventory, viewer, animation fields, NewShulkerBox,
Inventory, WithName, AddViewer, RemoveViewer, Activate, UseOnBlock, Tick,
open/close, Model, SideClosed and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..item.item import MaxCounter
from ..item.optional_colour import OptionalColour, optional_colours
from ..world.block import Block, LightDiffuser, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    new_break_info,
)
from .cube.face import Face
from .hash import HASH_SHULKER_BOX
from .model.shulker import Shulker as ShulkerModel


struct ShulkerBox(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    MaxCounter,
    ModelledBlock,
    NBTer,
):
    """A dye-able block that stores items; unlike other containers it keeps them when broken.
    """

    comptime BASE_HASH: UInt64 = HASH_SHULKER_BOX
    """Go `hashShulkerBox`."""
    comptime ModelType = ShulkerModel
    """The model type (Go `Model`)."""

    var colour: OptionalColour
    """The colour of the shulker box, or none."""
    var facing: Face
    """The direction the shulker box opens to, kept in NBT."""
    var custom_name: String
    """The custom name of the shulker box."""

    def __init__(
        out self,
        *,
        colour: OptionalColour = OptionalColour.NONE,
        facing: Face = Face.DOWN,
        custom_name: String = String(),
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.colour = colour
        self.facing = facing
        self.custom_name = custom_name

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return (
            self.hash() == other.hash()
            and self.facing == other.facing
            and self.custom_name == other.custom_name
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if case .Some(c) = self.colour.colour():
            return BlockState(String(t"minecraft:{c}_shulker_box"))
        return BlockState("minecraft:undyed_shulker_box")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.colour.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return ShulkerBox(colour=OptionalColour(Int(hash & 0x1F)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for colour in optional_colours():
            out.append(ShulkerBox(colour=colour))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(2, ALWAYS_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> ShulkerModel:
        """Returns the model of the block (Go `Model`)."""
        return ShulkerModel(facing=self.facing, progress=0)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(self.encode_block().name, 0)

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the NBT (Go `EncodeNBT`)."""
        # The inventory is not ported: Go writes a new box's, which is empty.
        _ = tag.put_list(root, "Items")
        _ = tag.put_string(root, "id", "ShulkerBox")
        _ = tag.put_byte(root, "facing", UInt8(Int(self.facing)))
        if self.custom_name.byte_length() != 0:
            _ = tag.put_string(root, "CustomName", self.custom_name)

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Decodes the NBT (Go `DecodeNBT`); the items are not ported."""
        var s = self
        s.facing = Face(0)
        if case .Some(t) = tag.get(root, "facing"):
            s.facing = Face(Int(tag.as_byte(t)))
        s.custom_name = String()
        if case .Some(t) = tag.get(root, "CustomName"):
            s.custom_name = tag.as_string(t)
        return s

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in optional_colours():
            out.append(ShulkerBox(colour=v))
        return out^
