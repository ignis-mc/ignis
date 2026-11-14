"""`Lantern`, ported from Dragonfly `server/block/lantern.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): Model, NeighbourUpdateTick, UseOnBlock, SideClosed and the
drops.
"""

from ..world.block import (
    Block,
    LightDiffuser,
    LightEmitter,
    LiquidDisplacer,
    NeighbourUpdateTicker,
)
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    break_block,
    break_block_no_drops,
    new_break_info,
)
from .fire_type import FireType, fire_types
from .hash import AnyBlock, HASH_LANTERN
from .model.lantern import Lantern as LanternModel
from .liquid import source_water_can_displace
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import face_solid_at, is_air
from .iron_chain import IronChain


struct Lantern(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    LiquidDisplacer,
    ModelledBlock,
    NeighbourUpdateTicker,
):
    """A light emitting block."""

    comptime BASE_HASH: UInt64 = HASH_LANTERN
    """Go `hashLantern`."""
    comptime ModelType = LanternModel
    """The model type (Go `Model`)."""

    var hanging: Bool
    """Whether the lantern hangs from a block."""
    var type: FireType
    """The type of fire in the lantern."""

    def __init__(
        out self, *, hanging: Bool = False, type: FireType = FireType.NORMAL
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.hanging = hanging
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var name = "minecraft:lantern"
        if self.type == FireType.SOUL:
            name = "minecraft:soul_lantern"
        return BlockState(name, Properties().with_bool("hanging", self.hanging))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (UInt64(1) if self.hanging else UInt64(0)) | UInt64(
            self.type.uint8()
        ) << 1

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Lantern(
            hanging=hash & 0x1 != 0, type=FireType(Int((hash >> 1) & 0x1))
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for f in fire_types():
            out.append(Lantern(hanging=False, type=f))
            out.append(Lantern(hanging=True, type=f))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(3.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return self.type.light_level()

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> LanternModel:
        """Returns the model of the block (Go `Model`)."""
        return LanternModel(hanging=self.hanging)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.type == FireType.SOUL:
            return EncodedItem("minecraft:soul_lantern", 0)
        return EncodedItem("minecraft:lantern", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for f in fire_types():
            out.append(Self(type=f))
        return out^

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks without support above or below (Go `NeighbourUpdateTick`)."""
        if self.hanging:
            var up = pos.side(Face.UP)
            if not tx.block_as[IronChain](up) and not face_solid_at(
                tx, up, Face.DOWN
            ):
                break_block(self, pos, tx)
        elif not face_solid_at(tx, pos.side(Face.DOWN), Face.UP):
            break_block(self, pos, tx)
