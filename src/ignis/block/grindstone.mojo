"""`Grindstone`, ported from Dragonfly `server/block/grindstone.go`.

TODO(world-runtime): Model, SideClosed, Activate, UseOnBlock,
NeighbourUpdateTick and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .block import horizontal_direction
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.axis import Axis
from .cube.direction import Direction, directions
from .grindstone_attachment import GrindstoneAttachment, grindstone_attachments
from .hash import HASH_GRINDSTONE
from .model.grindstone import Grindstone as GrindstoneModel
from .block import (
    Activatable,
    Placement,
    UsableOnBlock,
    UseContext,
    User,
    first_replaceable,
)
from ..world.world import World, WorldTypes
from .cube.face import Face
from .cube.pos import Pos
from ..mgl64 import Vec3
from .hash import AnyBlock


struct Grindstone(
    Activatable,
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    UsableOnBlock,
):
    """A block that repairs items and tools as well as removing enchantments from them.
    """

    comptime BASE_HASH: UInt64 = HASH_GRINDSTONE
    """Go `hashGrindstone`."""
    comptime ModelType = GrindstoneModel
    """The model type (Go `Model`)."""

    var attach: GrindstoneAttachment
    """How the grindstone is attached."""
    var facing: Direction
    """The direction the grindstone faces."""

    def __init__(
        out self,
        *,
        attach: GrindstoneAttachment = GrindstoneAttachment.STANDING,
        facing: Direction = Direction.NORTH,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.attach = attach
        self.facing = facing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:grindstone",
            Properties()
            .with_string("attachment", String(self.attach))
            .with_int(
                "direction", Int32(Int(horizontal_direction(self.facing)))
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.attach.uint8()) | UInt64(Int(self.facing)) << 2

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Grindstone(
            attach=GrindstoneAttachment(Int(hash & 0x3)),
            facing=Direction(Int((hash >> 2) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for attach in grindstone_attachments():
            for facing in directions():
                out.append(Grindstone(attach=attach, facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            2, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> GrindstoneModel:
        """Returns the model of the block (Go `Model`)."""
        var axis = Axis.Y
        if self.attach == GrindstoneAttachment.WALL:
            axis = self.facing.face().axis()
        return GrindstoneModel(axis=axis)

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Opens the block's window (Go `Activate`)."""
        ctx.open_container = True
        return True

    def use_on_block[
        T: WorldTypes
    ](
        self,
        pos: Pos,
        face: Face,
        click: Vec3,
        user: User,
        mut tx: World[T],
    ) -> List[Placement]:
        """Places the grindstone standing, hanging or on a wall by the clicked face (Go `UseOnBlock`).
        """
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var b = self.copy()
        var f = at.value()[1]
        b.facing = user.direction().opposite()
        if f == Face.DOWN:
            b.attach = GrindstoneAttachment.HANGING
        elif f != Face.UP:
            b.attach = GrindstoneAttachment.WALL
            b.facing = f.direction()
        return [Placement(at.value()[0], AnyBlock(Self.BASE_HASH, b.hash()))]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:grindstone", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
