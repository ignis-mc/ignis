"""`CopperTrapdoor`, ported from Dragonfly
`server/block/copper_trapdoor.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): Activate, SideClosed, Model, Wax, Strip,
RandomTick (attemptOxidation), EncodeItem and the drops.

TODO(world-runtime): UseOnBlock, Activate, SideClosed, Model, Wax, Strip,
RandomTick (attemptOxidation) and the drops.
"""

from .cube.face import Face
from .cube.pos import Pos
from .cube.rotation import Rotation
from ..mgl64 import Vec3
from ..world.world import World, WorldTypes
from .block import Placement, UsableOnBlock, first_replaceable, replaceable_with
from .hash import AnyBlock
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    HARVEST_LEVEL_STONE,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
    pickaxe_harvestable_from,
)
from .cube.direction import Direction, directions
from .hash import HASH_COPPER_TRAPDOOR
from .model.trapdoor import Trapdoor as TrapdoorModel
from .oxidation_type import OxidationType, oxidation_types
from .oxidizable import Oxidisable, copper_block_name


struct CopperTrapdoor(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    Oxidisable,
    UsableOnBlock,
):
    """A copper trapdoor, opened and closed by players."""

    comptime BASE_HASH: UInt64 = HASH_COPPER_TRAPDOOR
    """Go `hashCopperTrapdoor`."""
    comptime ModelType = TrapdoorModel
    """The model type (Go `Model`)."""

    var oxidation: OxidationType
    """The level of oxidation of the block."""
    var waxed: Bool
    """Whether the block is waxed, which stops it from oxidising."""
    var facing: Direction
    """The direction the trapdoor faces."""
    var open: Bool
    """Whether the trapdoor is open."""
    var top: Bool
    """Whether the trapdoor is in the top half of the block."""

    def __init__(
        out self,
        *,
        oxidation: OxidationType = OxidationType.UNOXIDISED,
        waxed: Bool = False,
        facing: Direction = Direction.NORTH,
        open: Bool = False,
        top: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.oxidation = oxidation
        self.waxed = waxed
        self.facing = facing
        self.open = open
        self.top = top

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            copper_block_name("copper_trapdoor", self.oxidation, self.waxed),
            Properties()
            .with_int("direction", Int32(3 - Int(self.facing)))
            .with_bool("open_bit", self.open)
            .with_bool("upside_down_bit", self.top),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.oxidation.uint8())
            | (UInt64(1) if self.waxed else UInt64(0)) << 2
            | UInt64(Int(self.facing)) << 3
            | (UInt64(1) if self.open else UInt64(0)) << 5
            | (UInt64(1) if self.top else UInt64(0)) << 6
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return CopperTrapdoor(
            oxidation=OxidationType(Int(hash & 0x3)),
            waxed=(hash >> 2) & 0x1 != 0,
            facing=Direction(Int((hash >> 3) & 0x3)),
            open=(hash >> 5) & 0x1 != 0,
            top=(hash >> 6) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for oxidation in oxidation_types():
            for waxed in [False, True]:
                for facing in directions():
                    for open in [False, True]:
                        for top in [False, True]:
                            out.append(
                                CopperTrapdoor(
                                    oxidation=oxidation,
                                    waxed=waxed,
                                    facing=facing,
                                    open=open,
                                    top=top,
                                )
                            )
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

    def model(self) -> TrapdoorModel:
        """Returns the model of the block (Go `Model`)."""
        return TrapdoorModel(facing=self.facing, open=self.open, top=self.top)

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
        """Places the trapdoor facing the user, at the top when clicked on
        the upper half of a side or under a block (Go `UseOnBlock`)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var f = at.value()[1]
        var b = self
        b.facing = user.direction().opposite()
        b.top = (click.y() > 0.5 and f != Face.UP) or f == Face.DOWN
        return [
            Placement(at.value()[0], AnyBlock(Self.BASE_HASH, b.hash()), False)
        ]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(
            copper_block_name("copper_trapdoor", self.oxidation, self.waxed), 0
        )

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for o in oxidation_types():
            out.append(Self(oxidation=o))
            out.append(Self(oxidation=o, waxed=True))
        return out^
