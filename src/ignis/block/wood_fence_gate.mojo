"""`WoodFenceGate`, ported from Dragonfly `server/block/wood_fence_gate.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): FlammabilityInfo and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import (
    Activatable,
    Instrumented,
    Placement,
    UsableOnBlock,
    UseContext,
    first_replaceable,
)
from .cube.face import Face
from .cube.pos import Pos
from .cube.rotation import Rotation
from .wall import Wall
from ..mgl64 import Vec3
from ..world.block import NeighbourUpdateTicker
from ..world.sound.block import FenceGateClose, FenceGateOpen
from ..world.world import World, WorldTypes

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
from .hash import HASH_WOOD_FENCE_GATE
from .model.fence_gate import FenceGate as FenceGateModel
from .wood_type import WoodType, wood_types
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct WoodFenceGate(
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
    NeighbourUpdateTicker,
    UsableOnBlock,
):
    """A wooden fence gate that blocks entities, opened and closed by players.
    """

    comptime BASE_HASH: UInt64 = HASH_WOOD_FENCE_GATE
    """Go `hashWoodFenceGate`."""
    comptime ModelType = FenceGateModel
    """The model type (Go `Model`)."""

    var wood: WoodType
    """The type of wood."""
    var facing: Direction
    """The direction the gate faces."""
    var open: Bool
    """Whether the gate is open."""
    var lowered: Bool
    """Whether the gate is lowered to fit between walls."""

    def __init__(
        out self,
        *,
        wood: WoodType = WoodType.OAK,
        facing: Direction = Direction.NORTH,
        open: Bool = False,
        lowered: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.wood = wood
        self.facing = facing
        self.open = open
        self.lowered = lowered

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bass`)."""
        return Instrument.BASS

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var name = String(t"minecraft:{self.wood}_fence_gate")
        if self.wood == WoodType.OAK:
            name = "minecraft:fence_gate"
        return BlockState(
            name^,
            Properties()
            .with_string("minecraft:cardinal_direction", String(self.facing))
            .with_bool("open_bit", self.open)
            .with_bool("in_wall_bit", self.lowered),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.wood.uint8())
            | UInt64(Int(self.facing)) << 4
            | (UInt64(1) if self.open else UInt64(0)) << 6
            | (UInt64(1) if self.lowered else UInt64(0)) << 7
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return WoodFenceGate(
            wood=WoodType(Int(hash & 0xF)),
            facing=Direction(Int((hash >> 4) & 0x3)),
            open=(hash >> 6) & 0x1 != 0,
            lowered=(hash >> 7) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for wood in wood_types():
            for facing in directions():
                for open in [False, True]:
                    for lowered in [False, True]:
                        out.append(
                            WoodFenceGate(
                                wood=wood,
                                facing=facing,
                                open=open,
                                lowered=lowered,
                            )
                        )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            2, ALWAYS_HARVESTABLE, AXE_EFFECTIVE
        ).with_blast_resistance(3)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> FenceGateModel:
        """Returns the model of the block (Go `Model`)."""
        return FenceGateModel(facing=self.facing, open=self.open)

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
        """Places the gate facing away from the user, lowered between walls
        (Go `UseOnBlock`)."""
        var at = first_replaceable(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var p = at.value()[0]
        var f = self
        f.facing = user.direction()
        f.lowered = f.should_be_lowered(p, tx)
        return [Placement(p, AnyBlock(Self.BASE_HASH, f.hash()), False)]

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Lowers or raises the gate as walls come and go (Go
        `NeighbourUpdateTick`)."""
        if self.should_be_lowered(pos, tx) != self.lowered:
            var f = self
            f.lowered = not f.lowered
            tx.set_block(pos, f)

    def should_be_lowered[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T]) -> Bool:
        """Reports whether a wall is beside the gate (Go `shouldBeLowered`)."""
        var left_side = self.facing.rotate_left().face()
        var left = Bool(tx.block_as[Wall](pos.side(left_side)))
        var right = Bool(tx.block_as[Wall](pos.side(left_side.opposite())))
        return left or right

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Opens or closes the gate, swinging away from the user (Go
        `Activate`)."""
        var f = self
        f.open = not f.open
        if f.open and f.facing.opposite() == ctx.user_rot.direction():
            f.facing = f.facing.opposite()
        tx.set_block(pos, f)
        if f.open:
            tx.play_sound(pos.vec3_centre(), FenceGateOpen(block=AnyBlock(f)))
            return True
        tx.play_sound(pos.vec3_centre(), FenceGateClose(block=AnyBlock(f)))
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.wood == WoodType.OAK:
            return EncodedItem("minecraft:fence_gate", 0)
        return EncodedItem(String(t"minecraft:{self.wood}_fence_gate"), 0)

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
            out.append(WoodFenceGate(wood=v))
        return out^

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
