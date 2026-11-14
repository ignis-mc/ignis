"""`WoodDoor`, ported from Dragonfly `server/block/wood_door.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): Activate, Model, FlammabilityInfo and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Activatable, Instrumented, UseContext
from .door_placement import door_hinge_right, door_placement_position
from ..world.sound.block import DoorClose, DoorOpen

from .cube.face import Face
from .cube.pos import Pos
from .cube.rotation import Rotation
from ..mgl64 import Vec3
from ..world.world import World, WorldTypes
from .block import (
    Placement,
    UsableOnBlock,
    User,
    face_solid_at,
    first_replaceable,
    is_air,
    replaceable_with,
)
from .hash import AnyBlock, HASH_WOOD_DOOR

from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import (
    Block,
    LightDiffuser,
    LiquidDisplacer,
    NeighbourUpdateTicker,
)
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    break_block,
    break_block_no_drops,
    new_break_info,
)
from .cube.direction import Direction, directions
from .model.door import Door as DoorModel
from .wood_type import WoodType, wood_types
from .liquid import source_water_can_displace


struct WoodDoor(
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
    """A wooden door that blocks entities, opened and closed by players."""

    comptime BASE_HASH: UInt64 = HASH_WOOD_DOOR
    """Go `hashWoodDoor`."""
    comptime ModelType = DoorModel
    """The model type (Go `Model`)."""

    var wood: WoodType
    """The type of wood."""
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
        wood: WoodType = WoodType.OAK,
        facing: Direction = Direction.NORTH,
        open: Bool = False,
        top: Bool = False,
        right: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.wood = wood
        self.facing = facing
        self.open = open
        self.top = top
        self.right = right

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bass`)."""
        return Instrument.BASS

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var name = String(t"minecraft:{self.wood}_door")
        if self.wood == WoodType.OAK:
            name = "minecraft:wooden_door"
        return BlockState(
            name^,
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
            UInt64(self.wood.uint8())
            | UInt64(Int(self.facing)) << 4
            | (UInt64(1) if self.open else UInt64(0)) << 6
            | (UInt64(1) if self.top else UInt64(0)) << 7
            | (UInt64(1) if self.right else UInt64(0)) << 8
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return WoodDoor(
            wood=WoodType(Int(hash & 0xF)),
            facing=Direction(Int((hash >> 4) & 0x3)),
            open=(hash >> 6) & 0x1 != 0,
            top=(hash >> 7) & 0x1 != 0,
            right=(hash >> 8) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for wood in wood_types():
            for facing in directions():
                for open in [False, True]:
                    for top in [False, True]:
                        for right in [False, True]:
                            out.append(
                                WoodDoor(
                                    wood=wood,
                                    facing=facing,
                                    open=open,
                                    top=top,
                                    right=right,
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
        user: User,
        mut tx: World[T],
    ) -> List[Placement]:
        """Places both halves of the door on a solid block, facing away
        from the user with the hinge chosen from its neighbours (Go
        `UseOnBlock`)."""
        var at = door_placement_position(
            tx, pos, face, AnyBlock(Self.BASE_HASH, self.hash())
        )
        if not at:
            return List[Placement]()
        var p = at.value()
        var lower = self
        lower.facing = user.direction()
        lower.right = door_hinge_right(tx, p, lower.facing)
        lower.top = False
        var upper = WoodDoor(
            wood=lower.wood, facing=lower.facing, top=True, right=lower.right
        )
        return [
            Placement(p, AnyBlock(Self.BASE_HASH, lower.hash()), True),
            Placement(
                p.side(Face.UP), AnyBlock(Self.BASE_HASH, upper.hash()), True
            ),
        ]

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Opens or closes both halves of the door (Go `Activate`)."""
        var d = self
        d.open = not d.open
        tx.set_block(pos, d)
        var other_pos = pos.side(Face.DOWN if d.top else Face.UP)
        if case .Some(other) = tx.block_as[WoodDoor](other_pos):
            var o = other
            o.open = d.open
            tx.set_block(other_pos, o)
        if d.open:
            tx.play_sound(pos.vec3_centre(), DoorOpen(block=AnyBlock(d)))
            return True
        tx.play_sound(pos.vec3_centre(), DoorClose(block=AnyBlock(d)))
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.wood == WoodType.OAK:
            return EncodedItem("minecraft:wooden_door", 0)
        return EncodedItem(String(t"minecraft:{self.wood}_door"), 0)

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`); none for nether wood."""
        if not self.wood.flammable():
            return FuelInfo()
        return FuelInfo(10000)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in wood_types():
            out.append(WoodDoor(wood=v))
        return out^

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks without its other half or a solid block below (Go
        `NeighbourUpdateTick`)."""
        if self.top:
            if not tx.block_as[WoodDoor](pos.side(Face.DOWN)):
                break_block_no_drops(self, pos, tx)
        elif not face_solid_at(tx, pos.side(Face.DOWN), Face.UP):
            break_block(self, pos, tx)
        elif not tx.block_as[WoodDoor](pos.side(Face.UP)):
            break_block_no_drops(self, pos, tx)
