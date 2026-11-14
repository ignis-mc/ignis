"""`Bone`, ported from Dragonfly `server/block/bone.go`.

TODO(world-runtime): Instrument, UseOnBlock and the drops.
"""

from ..world.block import Block
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
from .hash import HASH_BONE
from .model.solid import Solid as SolidModel


struct Bone(
    Block, Breakable, Equatable, ImplicitlyCopyable, Item, ModelledBlock
):
    """A decorative block that can be crafted from bone meal."""

    comptime BASE_HASH: UInt64 = HASH_BONE
    """Go `hashBone`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var axis: Axis
    """The axis the block faces."""

    def __init__(out self, *, axis: Axis = Axis.Y):
        """Creates the block; omitted fields take Go zero values.

        Args:
            axis: The axis the block faces.
        """
        self.axis = axis

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state.
        """
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState(
            "minecraft:bone_block",
            Properties()
            .with_string("pillar_axis", String(self.axis))
            .with_int("deprecated", 0),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(Int(self.axis))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Bone(axis=Axis(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for axis in axes():
            out.append(Bone(axis=axis))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(2, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:bone_block", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
