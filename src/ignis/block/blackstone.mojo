"""`Blackstone`, ported from Dragonfly `server/block/blackstone.go`.

TODO(world-runtime): the drops (gilded blackstone drops gold nuggets).
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .blackstone_type import BlackstoneType, blackstone_types
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_BLACKSTONE
from .model.solid import Solid as SolidModel


struct Blackstone(
    Block, Breakable, Equatable, ImplicitlyCopyable, Item, ModelledBlock
):
    """A naturally generating block in the nether, similar to cobblestone."""

    comptime BASE_HASH: UInt64 = HASH_BLACKSTONE
    """Go `hashBlackstone`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var type: BlackstoneType
    """The type of blackstone."""

    def __init__(out self, *, type: BlackstoneType = BlackstoneType.NORMAL):
        """Creates the block; omitted fields take Go zero values."""
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(String(t"minecraft:{self.type}"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Blackstone(type=BlackstoneType(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for type in blackstone_types():
            out.append(Blackstone(type=type))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        var hardness = 1.5
        if self.type == BlackstoneType.POLISHED:
            hardness = 2
        return new_break_info(
            hardness, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.type}"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for t in blackstone_types():
            out.append(Self(type=t))
        return out^
