"""`BrewingStand`, ported from Dragonfly `server/block/brewing_stand.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

The brewing (Go's embedded `*brewer`) is `block/brewer.mojo`: the
inventory lives with the world's block entity, the brew time and fuel are
NBT fields of the value. Go's `DecodeNBT` returns a stand without its slot
bits and keeps the value, so `Tick` sets them once; Ignis decodes the NBT
every tick, so `decode_nbt` keeps the bits of the state.
"""

from minecraft.nbt.tree import Tag, Tree

from ..item.inventory.inventory import Inventory
from ..mgl64 import Vec3
from ..world.block import Block, Container, LightDiffuser, NBTer, TickerBlock
from ..world.block_set import encode_block_nbt
from ..world.world import World, WorldTypes
from .block import (
    Activatable,
    BreakHandler,
    HopperExtractable,
    HopperInsertable,
    Placement,
    UsableOnBlock,
    UseContext,
    User,
    first_replaceable,
)
from .brewer import Brewer, brewer_extract, brewer_insert, tick_brewing
from .container import drop_contents
from .cube.face import Face
from .cube.pos import Pos
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_BREWING_STAND
from .model.brewing_stand import BrewingStand as BrewingStandModel
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct BrewingStand(
    Activatable,
    Block,
    BreakHandler,
    Breakable,
    Container,
    Equatable,
    HopperExtractable,
    HopperInsertable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    ModelledBlock,
    NBTer,
    TickerBlock,
    UsableOnBlock,
):
    """A block used for brewing potions, splash potions, and lingering potions.
    """

    comptime BASE_HASH: UInt64 = HASH_BREWING_STAND
    """Go `hashBrewingStand`."""
    comptime ModelType = BrewingStandModel
    """The model type (Go `Model`)."""

    var left_slot: Bool
    """Whether the left slot holds a potion."""
    var middle_slot: Bool
    """Whether the middle slot holds a potion."""
    var right_slot: Bool
    """Whether the right slot holds a potion."""
    var brewer: Brewer
    """The brew time and fuel (Go's `*brewer`)."""

    def __init__(
        out self,
        *,
        left_slot: Bool = False,
        middle_slot: Bool = False,
        right_slot: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.left_slot = left_slot
        self.middle_slot = middle_slot
        self.right_slot = right_slot
        self.brewer = Brewer()

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash() and self.brewer == other.brewer

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:brewing_stand",
            Properties()
            .with_bool("brewing_stand_slot_a_bit", self.left_slot)
            .with_bool("brewing_stand_slot_b_bit", self.middle_slot)
            .with_bool("brewing_stand_slot_c_bit", self.right_slot),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            (UInt64(1) if self.left_slot else UInt64(0))
            | (UInt64(1) if self.middle_slot else UInt64(0)) << 1
            | (UInt64(1) if self.right_slot else UInt64(0)) << 2
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return BrewingStand(
            left_slot=hash & 0x1 != 0,
            middle_slot=(hash >> 1) & 0x1 != 0,
            right_slot=(hash >> 2) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for left_slot in [False, True]:
            for middle_slot in [False, True]:
                for right_slot in [False, True]:
                    out.append(
                        BrewingStand(
                            left_slot=left_slot,
                            middle_slot=middle_slot,
                            right_slot=right_slot,
                        )
                    )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.5, ALWAYS_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> BrewingStandModel:
        """Returns the model of the block (Go `Model`)."""
        return BrewingStandModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:brewing_stand", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`); the world adds the
        `Items`."""
        _ = tag.put_string(root, "id", "BrewingStand")
        _ = tag.put_list(root, "Items")
        self.brewer.encode(tag, root)

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        var b = Self(
            left_slot=self.left_slot,
            middle_slot=self.middle_slot,
            right_slot=self.right_slot,
        )
        b.brewer = Brewer.decode(tag, root)
        return b^

    def inventory_size(self) -> Int:
        """Returns the ingredient, three bottle and fuel slots (Go
        `ContainerSize`)."""
        return 5

    def tick[
        T: WorldTypes
    ](self, current_tick: Int64, pos: Pos, mut tx: World[T]):
        """Shows which bottle slots are filled and brews (Go `Tick`)."""
        var found = tx.inventory(pos)
        if not found:
            return
        var b = self.copy()
        try:
            b.left_slot = not found.value().item(1).empty()
            b.middle_slot = not found.value().item(2).empty()
            b.right_slot = not found.value().item(3).empty()
        except:
            return
        if b.hash() != self.hash():
            tx.set_block(pos, b)
        tick_brewing(b.brewer, "brewing_stand", pos, tx)
        if b.brewer != self.brewer:
            tx.set_block_entity_nbt(pos, encode_block_nbt(b), notify=False)

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Opens the window (Go `Activate`)."""
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
        """Places a new brewing stand (Go `UseOnBlock`)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        return [
            Placement(at.value()[0], AnyBlock(Self.BASE_HASH, Self().hash()))
        ]

    def on_break[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], harvest: Bool):
        """Drops the contents (Go's break handler)."""
        tx.close_container_viewers(pos)
        drop_contents(pos, tx, pos.vec3_centre())

    def insert_item[
        T: WorldTypes
    ](
        self, mut hopper: Inventory, facing: Face, pos: Pos, mut tx: World[T]
    ) -> Bool:
        """Takes an item from a hopper (Go `brewer.InsertItem`)."""
        return brewer_insert(hopper, facing, pos, tx)

    def extract_item[
        T: WorldTypes
    ](self, mut hopper: Inventory, pos: Pos, mut tx: World[T]) -> Bool:
        """Gives a hopper a bottle (Go `brewer.ExtractItem`)."""
        return brewer_extract(hopper, pos, tx)

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
