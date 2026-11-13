"""`Wood`, ported from Dragonfly `server/block/wood.go`.

TODO(world-runtime): UseOnBlock, Strip, EncodeItem, FlammabilityInfo,
FuelInfo and the drops.
"""

from ..world.block import Block
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.axis import Axis
from .hash import HASH_WOOD
from .wood_type import WoodType, wood_types


struct Wood(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A block with the log texture on all six sides."""

    comptime BASE_HASH: UInt64 = HASH_WOOD
    """Go `hashWood`."""

    var wood: WoodType
    """The type of wood."""
    var stripped: Bool
    """Whether the bark has been stripped off."""
    var axis: Axis
    """The axis the block faces."""

    def __init__(
        out self,
        *,
        wood: WoodType = WoodType.OAK,
        stripped: Bool = False,
        axis: Axis = Axis.Y,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            wood: The type of wood.
            stripped: Whether the bark has been stripped off.
            axis: The axis the block faces.
        """
        self.wood = wood
        self.stripped = stripped
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
        var prefix = "stripped_" if self.stripped else ""
        var suffix = "wood"
        if self.wood == WoodType.CRIMSON or self.wood == WoodType.WARPED:
            suffix = "hyphae"
        return BlockState(
            String(t"minecraft:{prefix}{self.wood}_{suffix}"),
            Properties().with_string("pillar_axis", String(self.axis)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.wood.uint8())
            | (UInt64(1) if self.stripped else UInt64(0)) << 4
            | UInt64(Int(self.axis)) << 5
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Wood(
            wood=WoodType(Int(hash & 0xF)),
            stripped=(hash >> 4) & 0x1 != 0,
            axis=Axis(Int((hash >> 5) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for w in wood_types():
            if w == WoodType.BAMBOO:
                continue
            for axis in range(3):
                out.append(Wood(wood=w, stripped=True, axis=Axis(axis)))
                out.append(Wood(wood=w, stripped=False, axis=Axis(axis)))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(2.0, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)
