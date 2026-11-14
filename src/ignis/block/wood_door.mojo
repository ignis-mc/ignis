"""`WoodDoor`, ported from Dragonfly `server/block/wood_door.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): NeighbourUpdateTick, Activate, SideClosed,
Model, FlammabilityInfo and the drops.
"""

from .cube.face import Face
from .cube.pos import Pos
from .cube.rotation import Rotation
from ..mgl64 import Vec3
from ..world.world import World, WorldTypes
from .block import Placement, UsableOnBlock, first_replaceable, replaceable_with
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
from .hash import HASH_WOOD_DOOR
from .model.door import Door as DoorModel
from .wood_type import WoodType, wood_types


struct WoodDoor(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
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
        """Creates the block; omitted fields take Go zero values.

        Args:
            wood: The type of wood.
            facing: The direction the door faces.
            open: Whether the door is open.
            top: Whether this is the upper half of the door.
            right: Whether the hinge is on the right side.
        """
        self.wood = wood
        self.facing = facing
        self.open = open
        self.top = top
        self.right = right

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state.
        """
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
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
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.wood.uint8())
            | UInt64(Int(self.facing)) << 4
            | (UInt64(1) if self.open else UInt64(0)) << 6
            | (UInt64(1) if self.top else UInt64(0)) << 7
            | (UInt64(1) if self.right else UInt64(0)) << 8
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return WoodDoor(
            wood=WoodType(Int(hash & 0xF)),
            facing=Direction(Int((hash >> 4) & 0x3)),
            open=(hash >> 6) & 0x1 != 0,
            top=(hash >> 7) & 0x1 != 0,
            right=(hash >> 8) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
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
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(3, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> DoorModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
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
