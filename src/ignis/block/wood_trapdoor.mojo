"""`WoodTrapdoor`, ported from Dragonfly `server/block/wood_trapdoor.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): Activate, Model, FlammabilityInfo and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Activatable, Instrumented, UseContext
from ..world.sound.block import TrapdoorClose, TrapdoorOpen

from .cube.face import Face
from .cube.pos import Pos
from .cube.rotation import Rotation
from ..mgl64 import Vec3
from ..world.world import World, WorldTypes
from .block import (
    Placement,
    UsableOnBlock,
    User,
    first_replaceable,
    replaceable_with,
)
from .hash import AnyBlock

from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block, LightDiffuser
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
from .cube.direction import Direction, directions
from .hash import HASH_WOOD_TRAPDOOR
from .model.trapdoor import Trapdoor as TrapdoorModel
from .wood_type import WoodType, wood_types
from ..world.block import LiquidDisplacer
from .liquid import source_water_can_displace


struct WoodTrapdoor(
    Activatable,
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    ModelledBlock,
    UsableOnBlock,
):
    """A wooden trapdoor, opened and closed by players."""

    comptime BASE_HASH: UInt64 = HASH_WOOD_TRAPDOOR
    """Go `hashWoodTrapdoor`."""
    comptime ModelType = TrapdoorModel
    """The model type (Go `Model`)."""

    var wood: WoodType
    """The type of wood."""
    var facing: Direction
    """The direction the trapdoor faces."""
    var open: Bool
    """Whether the trapdoor is open."""
    var top: Bool
    """Whether the trapdoor is in the top half of the block."""

    def __init__(
        out self,
        *,
        wood: WoodType = WoodType.OAK,
        facing: Direction = Direction.NORTH,
        open: Bool = False,
        top: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.wood = wood
        self.facing = facing
        self.open = open
        self.top = top

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bass`)."""
        return Instrument.BASS

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var name = String(t"minecraft:{self.wood}_trapdoor")
        if self.wood == WoodType.OAK:
            name = "minecraft:trapdoor"
        return BlockState(
            name^,
            Properties()
            .with_int("direction", Int32(3 - Int(self.facing)))
            .with_bool("open_bit", self.open)
            .with_bool("upside_down_bit", self.top),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.wood.uint8())
            | UInt64(Int(self.facing)) << 4
            | (UInt64(1) if self.open else UInt64(0)) << 6
            | (UInt64(1) if self.top else UInt64(0)) << 7
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return WoodTrapdoor(
            wood=WoodType(Int(hash & 0xF)),
            facing=Direction(Int((hash >> 4) & 0x3)),
            open=(hash >> 6) & 0x1 != 0,
            top=(hash >> 7) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for wood in wood_types():
            for facing in directions():
                for open in [False, True]:
                    for top in [False, True]:
                        out.append(
                            WoodTrapdoor(
                                wood=wood, facing=facing, open=open, top=top
                            )
                        )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(3, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

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
        user: User,
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

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Opens or closes the trapdoor (Go `Activate`)."""
        var t = self
        t.open = not t.open
        tx.set_block(pos, t)
        if t.open:
            tx.play_sound(pos.vec3_centre(), TrapdoorOpen(block=AnyBlock(t)))
            return True
        tx.play_sound(pos.vec3_centre(), TrapdoorClose(block=AnyBlock(t)))
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.wood == WoodType.OAK:
            return EncodedItem("minecraft:trapdoor", 0)
        return EncodedItem(String(t"minecraft:{self.wood}_trapdoor"), 0)

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`); none for nether wood."""
        if not self.wood.flammable():
            return FuelInfo()
        return FuelInfo(15000)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in wood_types():
            out.append(WoodTrapdoor(wood=v))
        return out^

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
