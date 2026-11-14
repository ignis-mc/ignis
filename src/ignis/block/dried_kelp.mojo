"""`DriedKelp`, ported from Dragonfly `server/block/dried_kelp.go`.

TODO(world-runtime): FlammabilityInfo and the drops.
"""

from ..item.item import Compostable
from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    HOE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_DRIED_KELP
from .model.solid import Solid as SolidModel


struct DriedKelp(
    Block,
    Breakable,
    Compostable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
):
    """A block made from dried kelp."""

    comptime BASE_HASH: UInt64 = HASH_DRIED_KELP
    """Go `hashDriedKelp`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `DriedKelp{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:dried_kelp_block")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return DriedKelp()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [DriedKelp()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            0.5, ALWAYS_HARVESTABLE, HOE_EFFECTIVE
        ).with_blast_resistance(2.5)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 200 s."""
        return FuelInfo(200000)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.5

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:dried_kelp_block", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
