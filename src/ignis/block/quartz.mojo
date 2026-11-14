"""`Quartz`, `ChiseledQuartz`, `QuartzPillar`, ported from Dragonfly
`server/block/quartz.go`.

TODO(world-runtime): QuartzPillar.UseOnBlock and the drops.
"""

from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .cube.axis import Axis, axes
from .hash import HASH_CHISELED_QUARTZ, HASH_QUARTZ, HASH_QUARTZ_PILLAR
from .model.solid import Solid as SolidModel


struct Quartz(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    Smeltable,
):
    """A mineral block used only for decoration."""

    comptime BASE_HASH: UInt64 = HASH_QUARTZ
    """Go `hashQuartz`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var smooth: Bool
    """Whether the quartz is smooth quartz."""

    def __init__(out self, *, smooth: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.smooth = smooth

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var name = (
            "minecraft:smooth_quartz" if self.smooth else "minecraft:quartz_block"
        )
        return BlockState(name, Properties().with_string("pillar_axis", "y"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.smooth else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Quartz(smooth=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Quartz(), Quartz(smooth=True)]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        if self.smooth:
            return new_break_info(
                2, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
            ).with_blast_resistance(6)
        return new_break_info(0.8, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.smooth:
            return EncodedItem("minecraft:smooth_quartz", 0)
        return EncodedItem("minecraft:quartz_block", 0)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        if self.smooth:
            return SmeltInfo()
        return SmeltInfo(Stack(Quartz(smooth=True), 1), 0.1)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Quartz(smooth=True), Quartz()]


struct ChiseledQuartz(
    Block, Breakable, Equatable, ImplicitlyCopyable, Item, ModelledBlock
):
    """A chiseled variant of quartz."""

    comptime BASE_HASH: UInt64 = HASH_CHISELED_QUARTZ
    """Go `hashChiseledQuartz`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `ChiseledQuartz{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:chiseled_quartz_block",
            Properties().with_string("pillar_axis", "y"),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return ChiseledQuartz()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [ChiseledQuartz()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.8, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:chiseled_quartz_block", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]


struct QuartzPillar(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
):
    """A pillar variant of quartz."""

    comptime BASE_HASH: UInt64 = HASH_QUARTZ_PILLAR
    """Go `hashQuartzPillar`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var axis: Axis
    """The axis the pillar faces."""

    def __init__(out self, *, axis: Axis = Axis.Y):
        """Creates the block; omitted fields take Go zero values."""
        self.axis = axis

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:quartz_pillar",
            Properties().with_string("pillar_axis", String(self.axis)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.axis))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return QuartzPillar(axis=Axis(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for axis in axes():
            out.append(QuartzPillar(axis=axis))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.8, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:quartz_pillar", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
