"""`Lectern`, ported from Dragonfly `server/block/lectern.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `Book item.Stack` field, Model, SideClosed,
UseOnBlock, Activate, Punch, TurnPage, FlammabilityInfo and the drops (the
book).
"""

from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_int32
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
from .cube.direction import Direction, directions
from .hash import HASH_LECTERN
from .model.lectern import Lectern as LecternModel


struct Lectern(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    NBTer,
):
    """A librarian's job site block found in villages, used to hold books for multiple players to
    read in multiplayer."""

    comptime BASE_HASH: UInt64 = HASH_LECTERN
    """Go `hashLectern`."""
    comptime ModelType = LecternModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the lectern faces."""
    var page: Int
    """The page the book on the lectern is opened to."""

    def __init__(
        out self, *, facing: Direction = Direction.NORTH, page: Int = 0
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The direction the lectern faces.
            page: The page the book on the lectern is opened to.
        """
        self.facing = facing
        self.page = page

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return self.hash() == other.hash() and self.page == other.page

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState(
            "minecraft:lectern",
            Properties()
            .with_string("minecraft:cardinal_direction", String(self.facing))
            .with_byte("powered_bit", 0),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(Int(self.facing))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Lectern(facing=Direction(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for facing in directions():
            out.append(Lectern(facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(2.5, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def model(self) -> LecternModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return LecternModel()

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:lectern", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        # TODO(world-runtime): book and totalPages, once the lectern holds a
        # book.
        _ = tag.put_byte(root, "hasBook", 0)
        _ = tag.put_int(root, "page", Int32(self.page))
        _ = tag.put_string(root, "id", "Lectern")

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        var l = self.copy()
        l.page = Int(get_int32(tag, root, "page"))
        # TODO(world-runtime): the book.
        return l^
