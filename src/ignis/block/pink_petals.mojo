"""`PinkPetals`, ported from Dragonfly `server/block/pink_petals.go`.

TODO(world-runtime): UseOnBlock, BoneMeal, FlammabilityInfo and the drops.
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
from .cube.direction import Direction, directions
from .hash import AnyBlock, HASH_PINK_PETALS
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import face_solid_at, is_air
from .dirt import supports_vegetation


struct PinkPetals(
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
    """A decorative block that generates in cherry grove biomes."""

    comptime BASE_HASH: UInt64 = HASH_PINK_PETALS
    """Go `hashPinkPetals`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var additional_count: Int
    """The number of additional petals, 0 to 7; only 0 to 3 occur in-game."""
    var facing: Direction
    """The direction the petals face, opposite to the placing player."""

    def __init__(
        out self,
        *,
        additional_count: Int = 0,
        facing: Direction = Direction.NORTH,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.additional_count = additional_count
        self.facing = facing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:pink_petals",
            Properties()
            .with_int("growth", Int32(self.additional_count))
            .with_string("minecraft:cardinal_direction", String(self.facing)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.additional_count) | UInt64(Int(self.facing)) << 8

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return PinkPetals(
            additional_count=Int(hash & 0xFF),
            facing=Direction(Int((hash >> 8) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for additional_count in range(8):
            for facing in directions():
                out.append(
                    PinkPetals(additional_count=additional_count, facing=facing)
                )
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

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:pink_petals", 0)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.3

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def has_liquid_drops(self) -> Bool:
        """Returns True (Go `HasLiquidDrops`)."""
        return True

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks without soil below (Go `NeighbourUpdateTick`)."""
        if not supports_vegetation(
            AnyBlock(self), tx.block(pos.side(Face.DOWN)), tx
        ):
            break_block(self, pos, tx)
