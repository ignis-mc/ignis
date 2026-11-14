"""`Stonecutter`, ported from Dragonfly `server/block/stonecutter.go`.

TODO(world-runtime): Activate, UseOnBlock, Model, SideClosed and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_STONECUTTER
from .model.stonecutter import Stonecutter as StonecutterModel
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


struct Stonecutter(
    Activatable,
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
    UsableOnBlock,
):
    """A block used to cut stone-like materials into their slabs, stairs and walls.
    """

    comptime BASE_HASH: UInt64 = HASH_STONECUTTER
    """Go `hashStonecutter`."""
    comptime ModelType = StonecutterModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the stonecutter faces."""

    def __init__(out self, *, facing: Direction = Direction.NORTH):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:stonecutter_block",
            Properties().with_string(
                "minecraft:cardinal_direction", String(self.facing)
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.facing))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Stonecutter(facing=Direction(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for facing in directions():
            out.append(Stonecutter(facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(3.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def model(self) -> StonecutterModel:
        """Returns the model of the block (Go `Model`)."""
        return StonecutterModel()

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
        """Places the stonecutter facing the user (Go `UseOnBlock`)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var b = self.copy()
        b.facing = user.direction().opposite()
        return [Placement(at.value()[0], AnyBlock(Self.BASE_HASH, b.hash()))]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:stonecutter_block", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
