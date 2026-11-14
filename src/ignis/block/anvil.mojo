"""`Anvil`, ported from Dragonfly `server/block/anvil.go`.

TODO(world-runtime): Model, SideClosed, Activate, UseOnBlock,
NeighbourUpdateTick and the falling behaviour of `gravityAffected`, Damage and
the drops.
"""

from ..world.block import Block, LightDiffuser, NeighbourUpdateTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .anvil_type import AnvilType, anvil_types
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_ANVIL
from .model.anvil import Anvil as AnvilModel
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import gravity_fall


struct Anvil(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    NeighbourUpdateTicker,
):
    """A block that allows players to repair items, rename items, and combine enchantments.
    """

    comptime BASE_HASH: UInt64 = HASH_ANVIL
    """Go `hashAnvil`."""
    comptime ModelType = AnvilModel
    """The model type (Go `Model`)."""

    var type: AnvilType
    """How damaged the anvil is."""
    var facing: Direction
    """The direction the anvil faces."""

    def __init__(
        out self,
        *,
        type: AnvilType = AnvilType.UNDAMAGED,
        facing: Direction = Direction.NORTH,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.type = type
        self.facing = facing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            String(t"minecraft:{self.type}"),
            Properties().with_string(
                "minecraft:cardinal_direction", String(self.facing)
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.type.uint8()) | UInt64(Int(self.facing)) << 2

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Anvil(
            type=AnvilType(Int(hash & 0x3)),
            facing=Direction(Int((hash >> 2) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for type in anvil_types():
            for facing in directions():
                out.append(Anvil(type=type, facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(1200)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> AnvilModel:
        """Returns the model of the block (Go `Model`)."""
        return AnvilModel(facing=self.facing)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.type}"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for t in anvil_types():
            out.append(Self(type=t))
        return out^

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Falls when nothing holds it up (Go `NeighbourUpdateTick`)."""
        gravity_fall(self, pos, tx)
