"""`CopperGrate`, ported from Dragonfly `server/block/copper_grate.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): Wax, Strip, RandomTick (attemptOxidation) and the drops.
"""

from ..world.block import Block, LightDiffuser, RandomTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    HARVEST_LEVEL_STONE,
    PICKAXE_EFFECTIVE,
    new_break_info,
    pickaxe_harvestable_from,
)
from .hash import HASH_COPPER_GRATE
from .model.solid import Solid as SolidModel
from .oxidation_type import OxidationType, oxidation_types
from .oxidizable import Oxidisable, attempt_oxidation, copper_block_name
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face


struct CopperGrate(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    Oxidisable,
    RandomTicker,
):
    """A transparent copper block."""

    comptime BASE_HASH: UInt64 = HASH_COPPER_GRATE
    """Go `hashCopperGrate`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var oxidation: OxidationType
    """The level of oxidation of the block."""
    var waxed: Bool
    """Whether the block is waxed, which stops it from oxidising."""

    def __init__(
        out self,
        *,
        oxidation: OxidationType = OxidationType.UNOXIDISED,
        waxed: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.oxidation = oxidation
        self.waxed = waxed

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            copper_block_name("copper_grate", self.oxidation, self.waxed)
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.oxidation.uint8())
            | (UInt64(1) if self.waxed else UInt64(0)) << 2
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return CopperGrate(
            oxidation=OxidationType(Int(hash & 0x3)),
            waxed=(hash >> 2) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for waxed in [True, False]:
            for o in oxidation_types():
                out.append(CopperGrate(oxidation=o, waxed=waxed))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            3, pickaxe_harvestable_from(HARVEST_LEVEL_STONE), PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

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

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(
            copper_block_name("copper_grate", self.oxidation, self.waxed), 0
        )

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for o in oxidation_types():
            out.append(Self(oxidation=o))
            out.append(Self(oxidation=o, waxed=True))
        return out^

    def random_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """May oxidise (Go `RandomTick`)."""
        attempt_oxidation(pos, tx, self)
