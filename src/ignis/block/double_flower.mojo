"""`DoubleFlower`, ported from Dragonfly `server/block/double_flower.go`.

TODO(world-runtime): NeighbourUpdateTick, HasLiquidDrops, UseOnBlock, BoneMeal,
FlammabilityInfo and the drops.
"""

from ..item.item import Compostable
from ..world.block import Block, LightDiffuser, NeighbourUpdateTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    break_block,
    break_block_no_drops,
    new_break_info,
)
from .double_flower_type import DoubleFlowerType, double_flower_types
from .hash import AnyBlock, HASH_DOUBLE_FLOWER
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import face_solid_at, is_air
from .dirt import supports_vegetation


struct DoubleFlower(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidRemovable,
    ModelledBlock,
    NeighbourUpdateTicker,
):
    """A two block high flower consisting of an upper and lower part."""

    comptime BASE_HASH: UInt64 = HASH_DOUBLE_FLOWER
    """Go `hashDoubleFlower`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var upper_part: Bool
    """Whether this is the upper part of the plant."""
    var type: DoubleFlowerType
    """The type of the double flower."""

    def __init__(
        out self,
        *,
        upper_part: Bool = False,
        type: DoubleFlowerType = DoubleFlowerType.SUNFLOWER,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.upper_part = upper_part
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            String(t"minecraft:{self.type}"),
            Properties().with_bool("upper_block_bit", self.upper_part),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (UInt64(1) if self.upper_part else UInt64(0)) | UInt64(
            self.type.uint8()
        ) << 1

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return DoubleFlower(
            upper_part=hash & 0x1 != 0,
            type=DoubleFlowerType(Int((hash >> 1) & 0x7)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for d in double_flower_types():
            out.append(DoubleFlower(type=d, upper_part=True))
            out.append(DoubleFlower(type=d, upper_part=False))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.65

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.type}"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for f in double_flower_types():
            out.append(Self(type=f))
        return out^

    def has_liquid_drops(self) -> Bool:
        """Returns True (Go `HasLiquidDrops`)."""
        return True

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks without its other half or soil (Go `NeighbourUpdateTick`)."""
        if self.upper_part:
            var bottom = tx.block_as[DoubleFlower](pos.side(Face.DOWN))
            if (
                not bottom
                or bottom.value().type != self.type
                or bottom.value().upper_part
            ):
                break_block_no_drops(self, pos, tx)
            return
        var upper = tx.block_as[DoubleFlower](pos.side(Face.UP))
        if (
            not upper
            or upper.value().type != self.type
            or not upper.value().upper_part
        ):
            break_block_no_drops(self, pos, tx)
        elif not supports_vegetation(
            AnyBlock(self), tx.block(pos.side(Face.DOWN)), tx
        ):
            break_block(self, pos, tx)
