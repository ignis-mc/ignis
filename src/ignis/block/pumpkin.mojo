"""`Pumpkin`, ported from Dragonfly `server/block/pumpkin.go`.

TODO(world-runtime): Carve, UseOnBlock, Helmet, DefencePoints,
KnockBackResistance, Toughness, Instrument, CompostChance, EncodeItem and
the drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction
from .hash import HASH_PUMPKIN
from .model.solid import Solid as SolidModel


struct Pumpkin(Block, Breakable, Equatable, ImplicitlyCopyable, ModelledBlock):
    """A crop block; carved, it can be worn as a helmet."""

    comptime BASE_HASH: UInt64 = HASH_PUMPKIN
    """Go `hashPumpkin`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var carved: Bool
    """Whether the pumpkin is carved."""
    var facing: Direction
    """The direction the pumpkin faces."""

    def __init__(
        out self, *, carved: Bool = False, facing: Direction = Direction.NORTH
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            carved: Whether the pumpkin is carved.
            facing: The direction the pumpkin faces.
        """
        self.carved = carved
        self.facing = facing

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
        var name = (
            "minecraft:carved_pumpkin" if self.carved else "minecraft:pumpkin"
        )
        return BlockState(
            name,
            Properties().with_string(
                "minecraft:cardinal_direction", String(self.facing)
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (UInt64(1) if self.carved else UInt64(0)) | UInt64(
            Int(self.facing)
        ) << 1

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Pumpkin(
            carved=hash & 0x1 != 0, facing=Direction(Int((hash >> 1) & 0x3))
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for i in range(4):
            out.append(Pumpkin(facing=Direction(i)))
            out.append(Pumpkin(facing=Direction(i), carved=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(1, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()
