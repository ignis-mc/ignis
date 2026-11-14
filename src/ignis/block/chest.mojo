"""`Chest`, ported from Dragonfly `server/block/chest.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the inventory, pairing (paired, pairX, pairZ, pairInv) and
viewer fields, NewChest, Inventory, WithName, SideClosed, AddViewer,
RemoveViewer, Activate, UseOnBlock, open/close, Paired, pair, unpair, the break
handler, FlammabilityInfo and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_string
from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block, LightDiffuser, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_CHEST
from .model.chest import Chest as ChestModel
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct Chest(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    ModelledBlock,
    NBTer,
):
    """A container block which may be used to store items."""

    comptime BASE_HASH: UInt64 = HASH_CHEST
    """Go `hashChest`."""
    comptime ModelType = ChestModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the chest faces."""
    var custom_name: String
    """The custom name of the block, shown in its window."""

    def __init__(
        out self,
        *,
        facing: Direction = Direction.NORTH,
        custom_name: String = String(),
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.custom_name = custom_name

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return (
            self.hash() == other.hash()
            and self.custom_name == other.custom_name
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:chest",
            Properties().with_string(
                "minecraft:cardinal_direction", String(self.facing)
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.facing))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Chest(facing=Direction(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for facing in directions():
            out.append(Chest(facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(2.5, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> ChestModel:
        """Returns the model of the block (Go `Model`)."""
        return ChestModel()

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:chest", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        # TODO(world-runtime): the inventory; Go writes an empty one as an
        # empty list.
        _ = tag.put_list(root, "Items")
        _ = tag.put_string(root, "id", "Chest")
        if self.custom_name.byte_length() != 0:
            _ = tag.put_string(root, "CustomName", self.custom_name)
        # TODO(world-runtime): pairx and pairz of paired chests.

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        # TODO(world-runtime): the inventory and pairing.
        return Self(
            facing=self.facing, custom_name=get_string(tag, root, "CustomName")
        )

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
