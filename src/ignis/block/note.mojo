"""`Note`, ported from Dragonfly `server/block/note.go`.

TODO(world-runtime): playNote, instrument, Punch, Activate, RedstoneUpdate and
the drops.
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
from .hash import HASH_NOTE
from .model.solid import Solid as SolidModel


struct Note(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    NBTer,
):
    """A musical block that emits sounds when powered or punched."""

    comptime BASE_HASH: UInt64 = HASH_NOTE
    """Go `hashNote`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var pitch: Int
    """The current pitch the note block is set to, 0 to 24."""
    var powered: Bool
    """Whether the note block was powered during its last redstone update."""

    def __init__(out self, *, pitch: Int = 0, powered: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            pitch: The current pitch the note block is set to, 0 to 24.
            powered: Whether the note block was powered during its last redstone update.
        """
        self.pitch = pitch
        self.powered = powered

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return (
            self.hash() == other.hash()
            and self.pitch == other.pitch
            and self.powered == other.powered
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState("minecraft:noteblock")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Note()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Note()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.8, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:noteblock", 0)

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`)."""
        return FuelInfo(15000)

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the NBT (Go `EncodeNBT`)."""
        _ = tag.put_byte(root, "note", UInt8(self.pitch))
        _ = tag.put_byte(root, "powered", UInt8(1) if self.powered else 0)

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Decodes the NBT (Go `DecodeNBT`)."""
        var n = self
        n.pitch = 0
        if case .Some(t) = tag.get(root, "note"):
            n.pitch = Int(tag.as_byte(t))
        n.powered = False
        if case .Some(t) = tag.get(root, "powered"):
            n.powered = tag.as_byte(t) != 0
        return n

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Note(pitch=24)]
