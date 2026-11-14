"""`Leaves`, ported from Dragonfly `server/block/leaves.go`.

Go's `sourceWaterDisplacer` makes leaves a `LiquidDisplacer`; that trait
comes with liquids.

TODO(world-runtime): UseOnBlock, RandomTick (with findLog),
NeighbourUpdateTick, FlammabilityInfo, SideClosed, the drops (saplings, sticks,
apples).
"""

from ..item.item import Compostable
from ..item.tool import TYPE_HOE, TYPE_SHEARS
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    ToolFilter,
    new_break_info,
)
from .hash import HASH_LEAVES
from .leaves_type import LeavesType, leaves_types, poplar_leaves_types
from .model.leaves import Leaves as LeavesModel
from .wood_type import wood_types


struct Leaves(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """Blocks that grow as part of trees which mainly drop saplings and sticks.
    """

    comptime BASE_HASH: UInt64 = HASH_LEAVES
    """Go `hashLeaves`."""
    comptime ModelType = LeavesModel
    """The model type (Go `Model`)."""

    var type: LeavesType
    """The type of leaves."""
    var persistent: Bool
    """Whether the leaves were placed by a player and never decay."""
    var should_update: Bool
    """Whether the leaves should check for logs on the next random tick."""

    def __init__(
        out self,
        *,
        type: LeavesType = LeavesType.OAK,
        persistent: Bool = False,
        should_update: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.type = type
        self.persistent = persistent
        self.should_update = should_update

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            String(t"minecraft:{self.type}"),
            Properties()
            .with_bool("persistent_bit", self.persistent)
            .with_bool("update_bit", self.should_update),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.type.uint8())
            | (UInt64(1) if self.persistent else UInt64(0)) << 4
            | (UInt64(1) if self.should_update else UInt64(0)) << 5
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Leaves(
            type=LeavesType(Int(hash & 0xF)),
            persistent=(hash >> 4) & 0x1 != 0,
            should_update=(hash >> 5) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for flags in [
            (True, True),
            (True, False),
            (False, True),
            (False, False),
        ]:
            for t in leaves_types():
                out.append(
                    Leaves(type=t, persistent=flags[0], should_update=flags[1])
                )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            0.2, ALWAYS_HARVESTABLE, ToolFilter(TYPE_SHEARS, TYPE_HOE)
        )

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 1

    def model(self) -> LeavesModel:
        """Returns the model of the block (Go `Model`)."""
        return LeavesModel()

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.3

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.type}"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for w in wood_types():
            if case .Some(t) = w.leaves():
                out.append(Self(type=t, persistent=True))
        out.append(Self(type=LeavesType.AZALEA, persistent=True))
        out.append(Self(type=LeavesType.FLOWERING_AZALEA, persistent=True))
        for t in poplar_leaves_types():
            out.append(Self(type=t, persistent=True))
        return out^
