"""`CoralBlock`, ported from Dragonfly `server/block/coral_block.go`.

TODO(world-runtime): the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..world.block import Block, NeighbourUpdateTicker, ScheduledTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .coral_type import CoralType, coral_types
from .hash import HASH_CORAL_BLOCK
from .model.solid import Solid as SolidModel
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .water import Water


struct CoralBlock(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
    NeighbourUpdateTicker,
    ScheduledTicker,
):
    """A solid block that comes in 5 variants."""

    comptime BASE_HASH: UInt64 = HASH_CORAL_BLOCK
    """Go `hashCoralBlock`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var type: CoralType
    """The type of coral."""
    var dead: Bool
    """Whether the coral is dead."""

    def __init__(
        out self, *, type: CoralType = CoralType.TUBE, dead: Bool = False
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.type = type
        self.dead = dead

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var dead = "dead_" if self.dead else ""
        return BlockState(String(t"minecraft:{dead}{self.type}_coral_block"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.type.uint8())
            | (UInt64(1) if self.dead else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return CoralBlock(
            type=CoralType(Int(hash & 0x7)), dead=(hash >> 3) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for dead in [True, False]:
            for t in coral_types():
                out.append(CoralBlock(type=t, dead=dead))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.dead:
            return EncodedItem(
                String(t"minecraft:dead_{self.type}_coral_block"), 0
            )
        return EncodedItem(String(t"minecraft:{self.type}_coral_block"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for dead in [True, False]:
            for t in coral_types():
                out.append(Self(type=t, dead=dead))
        return out^

    def scheduled_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Dies without water next to it (Go `ScheduledTick`)."""
        var adjacent_water = False
        var br = tx.block_registry()
        for neighbour in pos.neighbours(tx.range()):
            if case .Some(l) = tx.liquid(neighbour):
                if br[].is_block[Water](l):
                    adjacent_water = True
        if not adjacent_water:
            var c = self.copy()
            c.dead = True
            tx.set_block(pos, c)

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Checks for water soon unless dead (Go `NeighbourUpdateTick`)."""
        if self.dead:
            return
        tx.schedule_block_update(pos, self, 2500)
