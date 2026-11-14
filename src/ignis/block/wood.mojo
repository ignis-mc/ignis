"""`Wood`, ported from Dragonfly `server/block/wood.go`.

TODO(world-runtime): UseOnBlock, Strip, FlammabilityInfo and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..item.charcoal import Charcoal
from ..item.smelting_info import Fuel, FuelInfo, SmeltInfo, Smeltable
from ..item.stack import Stack
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
from .cube.axis import Axis
from .hash import HASH_WOOD
from .model.solid import Solid as SolidModel
from .wood_type import WoodType, wood_types


struct Wood(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
    Smeltable,
):
    """A block with the log texture on all six sides."""

    comptime BASE_HASH: UInt64 = HASH_WOOD
    """Go `hashWood`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

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
        """Creates the block; omitted fields take Go zero values."""
        self.wood = wood
        self.stripped = stripped
        self.axis = axis

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bass`)."""
        return Instrument.BASS

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var prefix = "stripped_" if self.stripped else ""
        var suffix = "wood"
        if self.wood == WoodType.CRIMSON or self.wood == WoodType.WARPED:
            suffix = "hyphae"
        return BlockState(
            String(t"minecraft:{prefix}{self.wood}_{suffix}"),
            Properties().with_string("pillar_axis", String(self.axis)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.wood.uint8())
            | (UInt64(1) if self.stripped else UInt64(0)) << 4
            | UInt64(Int(self.axis)) << 5
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Wood(
            wood=WoodType(Int(hash & 0xF)),
            stripped=(hash >> 4) & 0x1 != 0,
            axis=Axis(Int((hash >> 5) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for w in wood_types():
            if w == WoodType.BAMBOO:
                continue
            for axis in range(3):
                out.append(Wood(wood=w, stripped=True, axis=Axis(axis)))
                out.append(Wood(wood=w, stripped=False, axis=Axis(axis)))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(2.0, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        var kind = "wood"
        if self.wood == WoodType.CRIMSON or self.wood == WoodType.WARPED:
            kind = "hyphae"
        if self.stripped:
            return EncodedItem(
                String(t"minecraft:stripped_{self.wood}_{kind}"), 0
            )
        return EncodedItem(String(t"minecraft:{self.wood}_{kind}"), 0)

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`); none for nether wood."""
        if not self.wood.flammable():
            return FuelInfo()
        return FuelInfo(15000)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        return SmeltInfo(Stack(Charcoal(), 1), 0.15)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in wood_types():
            if v != WoodType.BAMBOO:
                out.append(Wood(wood=v, stripped=True))
                out.append(Wood(wood=v))
        return out^
