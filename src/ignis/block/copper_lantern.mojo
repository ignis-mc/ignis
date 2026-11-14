"""`CopperLantern`, ported from Dragonfly `server/block/copper_lantern.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): Model, NeighbourUpdateTick, UseOnBlock, SideClosed, Wax,
Strip, RandomTick (attemptOxidation) and the drops.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
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
from .hash import HASH_COPPER_LANTERN
from .model.lantern import Lantern as LanternModel
from .oxidation_type import OxidationType, oxidation_types
from .oxidizable import Oxidisable, copper_block_name


struct CopperLantern(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    ModelledBlock,
    Oxidisable,
):
    """A light emitting block made of copper."""

    comptime BASE_HASH: UInt64 = HASH_COPPER_LANTERN
    """Go `hashCopperLantern`."""
    comptime ModelType = LanternModel
    """The model type (Go `Model`)."""

    var hanging: Bool
    """Whether the lantern hangs from a block."""
    var oxidation: OxidationType
    """The level of oxidation of the block."""
    var waxed: Bool
    """Whether the block is waxed, which stops it from oxidising."""

    def __init__(
        out self,
        *,
        hanging: Bool = False,
        oxidation: OxidationType = OxidationType.UNOXIDISED,
        waxed: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.hanging = hanging
        self.oxidation = oxidation
        self.waxed = waxed

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            copper_block_name("copper_lantern", self.oxidation, self.waxed),
            Properties().with_bool("hanging", self.hanging),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            (UInt64(1) if self.hanging else UInt64(0))
            | UInt64(self.oxidation.uint8()) << 1
            | (UInt64(1) if self.waxed else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return CopperLantern(
            hanging=hash & 0x1 != 0,
            oxidation=OxidationType(Int((hash >> 1) & 0x3)),
            waxed=(hash >> 3) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for waxed in [True, False]:
            for o in oxidation_types():
                out.append(
                    CopperLantern(hanging=False, oxidation=o, waxed=waxed)
                )
                out.append(
                    CopperLantern(hanging=True, oxidation=o, waxed=waxed)
                )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(3.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 15

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def can_oxidate(self) -> Bool:
        """Reports whether the block can still oxidise (Go `CanOxidate`)."""
        return not self.waxed

    def oxidation_level(self) -> OxidationType:
        """Returns the oxidation level (Go `OxidationLevel`)."""
        return self.oxidation

    def with_oxidation_level(self, o: OxidationType) -> Self:
        """Returns the block with another oxidation level (Go
        `WithOxidationLevel`)."""
        var b = self
        b.oxidation = o
        return b

    def model(self) -> LanternModel:
        """Returns the model of the block (Go `Model`)."""
        return LanternModel(hanging=self.hanging)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(
            copper_block_name("copper_lantern", self.oxidation, self.waxed), 0
        )

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for o in oxidation_types():
            out.append(Self(oxidation=o))
            out.append(Self(oxidation=o, waxed=True))
        return out^
