"""`Log`, ported from Dragonfly `server/block/log.go`.

TODO(world-runtime): Strip, FlammabilityInfo and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from .cube.face import Face
from .cube.pos import Pos
from .cube.rotation import Rotation
from ..mgl64 import Vec3
from ..world.world import World, WorldTypes
from .block import Placement, UsableOnBlock, first_replaceable, replaceable_with
from .hash import AnyBlock

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
from .hash import HASH_LOG
from .model.solid import Solid as SolidModel
from .wood_type import WoodType, wood_types


struct Log(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
    Smeltable,
    UsableOnBlock,
):
    """A naturally occurring block found in trees, used to craft other blocks.
    """

    comptime BASE_HASH: UInt64 = HASH_LOG
    """Go `hashLog`."""
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
        var suffix = "log"
        if self.wood == WoodType.CRIMSON or self.wood == WoodType.WARPED:
            suffix = "stem"
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
        return Log(
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
                out.append(Log(wood=w, stripped=True, axis=Axis(axis)))
                out.append(Log(wood=w, stripped=False, axis=Axis(axis)))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        var info = new_break_info(2, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)
        if self.wood == WoodType.MANGROVE and not self.stripped:
            return info.with_blast_resistance(0.4)
        return info

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def use_on_block[
        T: WorldTypes
    ](
        self,
        pos: Pos,
        face: Face,
        click: Vec3,
        user: Rotation,
        mut tx: World[T],
    ) -> List[Placement]:
        """Places the log along the clicked face's axis (Go `UseOnBlock`)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var b = self
        b.axis = at.value()[1].axis()
        return [
            Placement(at.value()[0], AnyBlock(Self.BASE_HASH, b.hash()), False)
        ]

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): 15 s if the wood burns."""
        if not self.wood.flammable():
            return FuelInfo()
        return FuelInfo(15000)

    def smelt_info(self) -> SmeltInfo:
        """Returns what smelting the block gives (Go `SmeltInfo`)."""
        return SmeltInfo(Stack(Charcoal(), 1), 0.15)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        var stem = self.wood == WoodType.CRIMSON or self.wood == WoodType.WARPED
        var suffix = "_stem" if stem else "_log"
        if not self.stripped:
            return EncodedItem(String(t"minecraft:{self.wood}{suffix}"), 0)
        return EncodedItem(String(t"minecraft:stripped_{self.wood}{suffix}"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for w in wood_types():
            if w != WoodType.BAMBOO:
                out.append(Self(wood=w, stripped=True))
                out.append(Self(wood=w))
        return out^
