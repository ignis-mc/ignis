"""`CopperDoor`, ported from Dragonfly `server/block/copper_door.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): NeighbourUpdateTick, Activate, SideClosed,
Model, Wax, Strip, RandomTick (attemptOxidation), EncodeItem and the drops.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, Activate, SideClosed,
Model, Wax, Strip, RandomTick (attemptOxidation) and the drops.
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
from .hash import HASH_COPPER_DOOR
from .model.door import Door as DoorModel
from .oxidation_type import OxidationType, oxidation_types
from .oxidizable import Oxidisable, copper_block_name


struct CopperDoor(
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
    """A copper door that blocks entities, opened and closed by players."""

    comptime BASE_HASH: UInt64 = HASH_COPPER_DOOR
    """Go `hashCopperDoor`."""
    comptime ModelType = DoorModel
    """The model type (Go `Model`)."""

    var oxidation: OxidationType
    """The level of oxidation of the block."""
    var waxed: Bool
    """Whether the block is waxed, which stops it from oxidising."""
    var facing: Direction
    """The direction the door faces."""
    var open: Bool
    """Whether the door is open."""
    var top: Bool
    """Whether this is the upper half of the door."""
    var right: Bool
    """Whether the hinge is on the right side."""

    def __init__(
        out self,
        *,
        oxidation: OxidationType = OxidationType.UNOXIDISED,
        waxed: Bool = False,
        facing: Direction = Direction.NORTH,
        open: Bool = False,
        top: Bool = False,
        right: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.oxidation = oxidation
        self.waxed = waxed
        self.facing = facing
        self.open = open
        self.top = top
        self.right = right

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            copper_block_name("copper_door", self.oxidation, self.waxed),
            Properties()
            .with_string(
                "minecraft:cardinal_direction",
                String(self.facing.rotate_right()),
            )
            .with_bool("door_hinge_bit", self.right)
            .with_bool("open_bit", self.open)
            .with_bool("upper_block_bit", self.top),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.oxidation.uint8())
            | (UInt64(1) if self.waxed else UInt64(0)) << 2
            | UInt64(Int(self.facing)) << 3
            | (UInt64(1) if self.open else UInt64(0)) << 5
            | (UInt64(1) if self.top else UInt64(0)) << 6
            | (UInt64(1) if self.right else UInt64(0)) << 7
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return CopperDoor(
            oxidation=OxidationType(Int(hash & 0x3)),
            waxed=(hash >> 2) & 0x1 != 0,
            facing=Direction(Int((hash >> 3) & 0x3)),
            open=(hash >> 5) & 0x1 != 0,
            top=(hash >> 6) & 0x1 != 0,
            right=(hash >> 7) & 0x1 != 0,
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
                            for right in [False, True]:
                                out.append(
                                    CopperDoor(
                                        oxidation=oxidation,
                                        waxed=waxed,
                                        facing=facing,
                                        open=open,
                                        top=top,
                                        right=right,
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

    def model(self) -> DoorModel:
        """Returns the model of the block (Go `Model`)."""
        return DoorModel(facing=self.facing, open=self.open, right=self.right)

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
        """Places both halves of the door on a solid block, facing away
        from the user (Go `UseOnBlock` with `doorPlacementPosition`; the
        hinge is not chosen from neighbours yet, Go `doorHingeRight`)."""
        var me = AnyBlock(Self.BASE_HASH, self.hash())
        var at = first_replaceable(tx, pos, face, me)
        if not at or at.value()[1] != Face.UP:
            return List[Placement]()
        var p = at.value()[0]
        if not replaceable_with(tx, p.side(Face.UP), me):
            return List[Placement]()
        var below = p.side(Face.DOWN)
        var br = tx.block_registry()
        var rid = tx.block(below)
        if not T.Blocks.face_solid(
            br[].kind(rid), br[].state_hash(rid), below, Face.UP, tx.source()
        ):
            return List[Placement]()
        var lower = self
        lower.facing = user.direction()
        lower.top = False
        var upper = lower
        upper.top = True
        return [
            Placement(p, AnyBlock(Self.BASE_HASH, lower.hash()), True),
            Placement(
                p.side(Face.UP), AnyBlock(Self.BASE_HASH, upper.hash()), True
            ),
        ]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(
            copper_block_name("copper_door", self.oxidation, self.waxed), 0
        )

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for o in oxidation_types():
            out.append(Self(oxidation=o))
            out.append(Self(oxidation=o, waxed=True))
        return out^
