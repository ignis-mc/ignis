"""`Sandstone`, ported from Dragonfly `server/block/sandstone.go`.

TODO(world-runtime): the drops.
"""

from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .hash import HASH_SANDSTONE
from .model.solid import Solid as SolidModel
from .sandstone_type import SandstoneType, sandstone_types


struct Sandstone(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    Smeltable,
):
    """A solid block commonly found in deserts and beaches underneath sand."""

    comptime BASE_HASH: UInt64 = HASH_SANDSTONE
    """Go `hashSandstone`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var type: SandstoneType
    """The type of sandstone."""
    var red: Bool
    """Whether the sandstone is red sandstone."""

    def __init__(
        out self,
        *,
        type: SandstoneType = SandstoneType.NORMAL,
        red: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.type = type
        self.red = red

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var prefix = String()
        if self.type != SandstoneType.NORMAL:
            prefix = String(t"{self.type}_")
        var name = "red_sandstone" if self.red else "sandstone"
        return BlockState(String(t"minecraft:{prefix}{name}"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.type.uint8())
            | (UInt64(1) if self.red else UInt64(0)) << 2
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Sandstone(
            type=SandstoneType(Int(hash & 0x3)), red=(hash >> 2) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for red in [True, False]:
            for t in sandstone_types():
                out.append(Sandstone(type=t, red=red))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        if self.type == SandstoneType.SMOOTH:
            return new_break_info(
                2, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
            ).with_blast_resistance(6)
        return new_break_info(0.8, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        var prefix = String()
        if self.type != SandstoneType.NORMAL:
            prefix = String(t"{self.type}_")
        if self.red:
            return EncodedItem(String(t"minecraft:{prefix}red_sandstone"), 0)
        return EncodedItem(String(t"minecraft:{prefix}sandstone"), 0)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        if self.type == SandstoneType.NORMAL:
            return SmeltInfo(
                Stack(Sandstone(type=SandstoneType.SMOOTH, red=self.red), 1),
                0.1,
            )
        return SmeltInfo()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in sandstone_types():
            out.append(Sandstone(type=v, red=True))
            out.append(Sandstone(type=v))
        return out^
