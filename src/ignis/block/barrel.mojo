"""`Barrel`, ported from Dragonfly `server/block/barrel.go`.

TODO(world-runtime): the inventory and viewer fields, NewBarrel, Inventory,
WithName, open/close, AddViewer, RemoveViewer, Activate, UseOnBlock, , the
break handler, FlammabilityInfo and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_string
from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block, NBTer
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
from .cube.face import Face
from .hash import HASH_BARREL
from .model.solid import Solid as SolidModel


struct Barrel(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    NBTer,
):
    """A fisherman's job site block, used to store items."""

    comptime BASE_HASH: UInt64 = HASH_BARREL
    """Go `hashBarrel`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var facing: Face
    """The direction the barrel faces."""
    var open: Bool
    """Whether the barrel is open."""
    var custom_name: String
    """The custom name of the block, shown in its window."""

    def __init__(
        out self,
        *,
        facing: Face = Face.DOWN,
        open: Bool = False,
        custom_name: String = String(),
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The direction the barrel faces.
            open: Whether the barrel is open.
            custom_name: The custom name of the block, shown in its window.
        """
        self.facing = facing
        self.open = open
        self.custom_name = custom_name

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return (
            self.hash() == other.hash()
            and self.custom_name == other.custom_name
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState(
            "minecraft:barrel",
            Properties()
            .with_byte("open_bit", UInt8(self.open))
            .with_int("facing_direction", Int32(Int(self.facing))),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.open else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Barrel(facing=Face(Int(hash & 0x7)), open=(hash >> 3) & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for i in range(6):
            out.append(Barrel(facing=Face(i)))
            out.append(Barrel(facing=Face(i), open=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(2.5, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:barrel", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        # TODO(world-runtime): the inventory; Go writes an empty one as an
        # empty list.
        _ = tag.put_list(root, "Items")
        _ = tag.put_string(root, "id", "Barrel")
        if self.custom_name.byte_length() != 0:
            _ = tag.put_string(root, "CustomName", self.custom_name)

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        return Self(
            facing=self.facing, custom_name=get_string(tag, root, "CustomName")
        )
