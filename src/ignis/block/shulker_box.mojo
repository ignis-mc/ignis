"""`ShulkerBox`, ported from Dragonfly `server/block/shulker_box.go`.

Differences from Go:

- The contents live with the world's block entity; broken (outside
  creative) the box drops as an item whose NBT holds them, and placed from
  such an item it gets them back (Go keeps the inventory in the value).
  The drop happens in `on_break`, so `Dropper.drops` is empty.
- Go animates the lid with scheduled ticks that grow the model and push
  entities, and plays the close sound once the lid is shut; Ignis opens
  and closes the lid at once (the client animates it) and plays the close
  sound on closing. The model keeps progress 0.
- Go's slot validator (no shulker boxes inside) is checked by the item
  stack request handler.
- Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait
  comes with liquids.
"""

from minecraft.nbt.tree import Tag, Tree

from ..item.item import MaxCounter
from ..item.stack import Stack
from ..item.tool import ToolInfo
from ..mgl64 import Vec3
from ..world.sound.block import ShulkerBoxClose, ShulkerBoxOpen
from ..world.viewer import BLOCK_ACTION_CLOSE, BLOCK_ACTION_OPEN
from ..world.world import World, WorldTypes
from ..world.block_set import encode_block_nbt
from .block import (
    Activatable,
    BreakHandler,
    Openable,
    Placement,
    UsableOnBlock,
    UseContext,
    User,
    first_replaceable,
)
from .cube.pos import Pos
from ..item.optional_colour import OptionalColour, optional_colours
from ..world.block import Block, Container, LightDiffuser, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    Dropper,
    PICKAXE_EFFECTIVE,
    new_break_info,
)
from .cube.face import Face
from .hash import AnyBlock, HASH_SHULKER_BOX
from .model.shulker import Shulker as ShulkerModel


struct ShulkerBox(
    Activatable,
    Block,
    BreakHandler,
    Breakable,
    Container,
    Dropper,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    MaxCounter,
    ModelledBlock,
    NBTer,
    Openable,
    UsableOnBlock,
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

    def inventory_size(self) -> Int:
        """Returns the box's 27 slots (Go `ContainerSize`)."""
        return 27

    def drops(self, tool: ToolInfo, silk_touch: Bool) -> List[Stack]:
        """Drops nothing here: `on_break` drops the box with its contents."""
        return List[Stack]()

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Opens the box unless a block that diffuses light is in front of
        its lid (Go `Activate`)."""
        var br = tx.block_registry()
        if br[].filtering_block(tx.block(pos.side(self.facing))) <= 2:
            ctx.open_container = True
        return True

    def use_on_block[
        T: WorldTypes
    ](
        self,
        pos: Pos,
        face: Face,
        click: Vec3,
        user: User,
        mut tx: World[T],
    ) -> List[Placement]:
        """Places the box with its lid on the clicked face, holding what the
        item held (Go `UseOnBlock`)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var s = self.copy()
        s.facing = face
        var nbt = user.held.item_nbt()
        if not nbt.is_empty():
            try:
                s = s.decode_nbt(nbt, nbt.root())
                s.facing = face
            except:
                pass
        var t = encode_block_nbt(s)
        if not nbt.is_empty():
            if case .Some(items) = nbt.get(nbt.root(), "Items"):
                try:
                    _ = t.remove(t.root(), "Items")
                    _ = t.put_tree(t.root(), "Items", nbt, items)
                except:
                    pass
        return [
            Placement(
                at.value()[0],
                AnyBlock(Self.BASE_HASH, s.hash()),
                nbt=t^,
                contents=True,
            )
        ]

    def opened[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Opens the lid (Go `open`)."""
        for v in tx.viewers(pos.vec3()):
            tx.viewer(v).view_block_action(pos, BLOCK_ACTION_OPEN)
        tx.play_sound(pos.vec3_centre(), ShulkerBoxOpen())

    def closed[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Closes the lid (Go `close`; Go plays the sound once it is shut)."""
        for v in tx.viewers(pos.vec3()):
            tx.viewer(v).view_block_action(pos, BLOCK_ACTION_CLOSE)
        tx.play_sound(pos.vec3_centre(), ShulkerBoxClose())

    def on_break[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], harvest: Bool):
        """Drops the box as an item that keeps the contents (Go `oneOf(s)`
        with the inventory in the value)."""
        tx.close_container_viewers(pos)
        if not harvest:
            return
        var it = Stack(ShulkerBox(colour=self.colour), 1)
        if case .Some(t) = tx.item_nbt(pos):
            it = it.with_item_nbt(t.copy())
        tx.drop_item(pos.vec3_centre(), it)

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the NBT (Go `EncodeNBT`); the world adds the `Items`."""
        _ = tag.put_list(root, "Items")
        _ = tag.put_string(root, "id", "ShulkerBox")
        _ = tag.put_byte(root, "facing", UInt8(Int(self.facing)))
        if self.custom_name.byte_length() != 0:
            _ = tag.put_string(root, "CustomName", self.custom_name)

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Decodes the NBT (Go `DecodeNBT`); the world reads the `Items`."""
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
