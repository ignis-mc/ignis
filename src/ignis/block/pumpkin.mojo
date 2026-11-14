"""`Pumpkin`, ported from Dragonfly `server/block/pumpkin.go`.

TODO(world-runtime): Carve, UseOnBlock, Instrument and the drops.
"""

from ..item.armour import HelmetType
from ..item.item import Compostable
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
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


struct Pumpkin(
    Block,
    Breakable,
    Compostable,
    Equatable,
    HelmetType,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
):
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

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.carved:
            return EncodedItem("minecraft:carved_pumpkin", 0)
        return EncodedItem("minecraft:pumpkin", 0)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.65

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Pumpkin(carved=True), Pumpkin()]

    def helmet(self) -> Bool:
        """Reports whether the pumpkin is worn as a helmet (Go `Helmet`)."""
        return self.carved

    def defence_points(self) -> Float64:
        """Returns the defence points (Go `DefencePoints`): none."""
        return 0

    def toughness(self) -> Float64:
        """Returns the toughness (Go `Toughness`): none."""
        return 0

    def knock_back_resistance(self) -> Float64:
        """Returns the knock-back resistance (Go `KnockBackResistance`)."""
        return 0
