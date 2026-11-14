"""`IronChain`, ported from Dragonfly `server/block/iron_chain.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): SideClosed, UseOnBlock, Model and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.axis import Axis, axes
from .hash import HASH_IRON_CHAIN
from .model.chain import Chain as ChainModel


struct IronChain(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """A metallic decoration block."""

    comptime BASE_HASH: UInt64 = HASH_IRON_CHAIN
    """Go `hashIronChain`."""
    comptime ModelType = ChainModel
    """The model type (Go `Model`)."""

    var axis: Axis
    """The axis the chain faces."""

    def __init__(out self, *, axis: Axis = Axis.Y):
        """Creates the block; omitted fields take Go zero values."""
        self.axis = axis

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:iron_chain",
            Properties().with_string("pillar_axis", String(self.axis)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.axis))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return IronChain(axis=Axis(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for axis in axes():
            out.append(IronChain(axis=axis))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> ChainModel:
        """Returns the model of the block (Go `Model`)."""
        return ChainModel(axis=self.axis)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:iron_chain", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
