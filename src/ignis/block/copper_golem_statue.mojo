"""`CopperGolemStatue`, ported from Dragonfly
`server/block/copper_golem_statue.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): UseOnBlock, Model, Wax, Strip and the drops.
"""

from .block import Activatable, UseContext
from .copper_golem_pose import copper_golem_poses


from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_int32
from ..world.block import Block, LightDiffuser, NBTer, RandomTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    new_break_info,
)
from .copper_golem_pose import CopperGolemPose
from .cube.direction import Direction, directions
from .hash import HASH_COPPER_GOLEM_STATUE
from .model.solid import Solid as SolidModel
from .oxidation_type import OxidationType, oxidation_types
from .oxidizable import Oxidisable, attempt_oxidation, copper_block_name
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face


struct CopperGolemStatue(
    Activatable,
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    NBTer,
    Oxidisable,
    RandomTicker,
):
    """A decorative statue left behind by a copper golem."""

    comptime BASE_HASH: UInt64 = HASH_COPPER_GOLEM_STATUE
    """Go `hashCopperGolemStatue`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the statue faces."""
    var pose: CopperGolemPose
    """The pose of the statue, kept in NBT."""
    var oxidation: OxidationType
    """The level of oxidation of the block."""
    var waxed: Bool
    """Whether the block is waxed, which stops it from oxidising."""

    def __init__(
        out self,
        *,
        facing: Direction = Direction.NORTH,
        pose: CopperGolemPose = CopperGolemPose.STANDING,
        oxidation: OxidationType = OxidationType.UNOXIDISED,
        waxed: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.pose = pose
        self.oxidation = oxidation
        self.waxed = waxed

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash() and self.pose == other.pose

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Moves the statue to its next pose with an empty hand (Go
        `Activate`)."""
        if not ctx.held.empty():
            return False
        var poses = copper_golem_poses()
        var next = Int(self.pose.uint8()) + 1
        if next >= len(poses):
            next = 0
        var c = self
        c.pose = poses[next]
        tx.set_block(pos, c)
        return True

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            copper_block_name(
                "copper_golem_statue", self.oxidation, self.waxed
            ),
            Properties().with_string(
                "minecraft:cardinal_direction", String(self.facing)
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(Int(self.facing))
            | UInt64(self.oxidation.uint8()) << 2
            | (UInt64(1) if self.waxed else UInt64(0)) << 4
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return CopperGolemStatue(
            facing=Direction(Int(hash & 0x3)),
            oxidation=OxidationType(Int((hash >> 2) & 0x3)),
            waxed=(hash >> 4) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for waxed in [True, False]:
            for o in oxidation_types():
                for d in directions():
                    out.append(
                        CopperGolemStatue(facing=d, oxidation=o, waxed=waxed)
                    )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            3, ALWAYS_HARVESTABLE, PICKAXE_EFFECTIVE
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
            copper_block_name(
                "copper_golem_statue", self.oxidation, self.waxed
            ),
            0,
        )

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for o in oxidation_types():
            out.append(Self(oxidation=o))
            out.append(Self(oxidation=o, waxed=True))
        return out^

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        _ = tag.put_int(root, "Pose", Int32(self.pose.uint8()))
        _ = tag.put_string(root, "id", "CopperGolemStatue")

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        var c = self.copy()
        c.pose = CopperGolemPose(Int(get_int32(tag, root, "Pose")))
        return c^

    def random_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """May oxidise (Go `RandomTick`)."""
        attempt_oxidation(pos, tx, self)
