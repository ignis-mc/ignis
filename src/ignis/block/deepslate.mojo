"""`Deepslate`, ported from Dragonfly `server/block/deepslate.go`.

TODO(world-runtime): UseOnBlock, EncodeItem, SmeltInfo and the `oneOf`
drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.axis import Axis, axes
from .deepslate_type import DeepslateType, deepslate_types
from .hash import HASH_DEEPSLATE
from .model.solid import Solid as SolidModel


struct Deepslate(
    Block, Breakable, Equatable, ImplicitlyCopyable, ModelledBlock
):
    """A stone type found deep underground in the world."""

    comptime BASE_HASH: UInt64 = HASH_DEEPSLATE
    """Go `hashDeepslate`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var type: DeepslateType
    """The type of deepslate."""
    var axis: Axis
    """The axis normal deepslate faces; unused by other types."""

    def __init__(
        out self,
        *,
        type: DeepslateType = DeepslateType.NORMAL,
        axis: Axis = Axis.Y,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            type: The type of deepslate.
            axis: The axis normal deepslate faces; unused by other types.
        """
        self.type = type
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
        if self.type == DeepslateType.NORMAL:
            return BlockState(
                "minecraft:deepslate",
                Properties().with_string("pillar_axis", String(self.axis)),
            )
        return BlockState(String(t"minecraft:{self.type}"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.type.uint8()) | UInt64(Int(self.axis)) << 2

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Deepslate(
            type=DeepslateType(Int(hash & 0x3)),
            axis=Axis(Int((hash >> 2) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for t in deepslate_types():
            if t == DeepslateType.NORMAL:
                for axis in axes():
                    out.append(Deepslate(type=t, axis=axis))
            else:
                out.append(Deepslate(type=t))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        if self.type == DeepslateType.NORMAL:
            return new_break_info(
                3, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
            ).with_blast_resistance(6)
        return new_break_info(
            3.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()
