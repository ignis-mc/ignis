"""`Jukebox`, ported from Dragonfly `server/block/jukebox.go`.

TODO(world-runtime): the `Item item.Stack` field, InsertItem, ExtractItem,
Activate, Disc, the break handler dropping the disc and the drops.
"""

from minecraft.nbt.tree import Tag, Tree

from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_JUKEBOX
from .model.solid import Solid as SolidModel


struct Jukebox(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    NBTer,
):
    """A block used to play music discs."""

    comptime BASE_HASH: UInt64 = HASH_JUKEBOX
    """Go `hashJukebox`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `Jukebox{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:jukebox")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Jukebox()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Jukebox()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            2, ALWAYS_HARVESTABLE, AXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:jukebox", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        _ = tag.put_string(root, "id", "Jukebox")
        # TODO(world-runtime): RecordItem, once the jukebox holds a disc.

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        # TODO(world-runtime): the disc in RecordItem.
        return self.copy()
