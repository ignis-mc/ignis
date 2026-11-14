"""`PumpkinSeeds`, ported from Dragonfly `server/block/pumpkin_seeds.go`.

TODO(world-runtime): the `crop` helpers (NeighbourUpdateTick, HasLiquidDrops,
CalculateGrowthChance), GrowthStage, SameCrop, RandomTick, BoneMeal, UseOnBlock
and the drops.
"""

from ..item.item import Compostable
from ..world.block import (
    Block,
    LightDiffuser,
    NeighbourUpdateTicker,
    RandomTicker,
)
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    break_block,
    new_break_info,
)
from .cube.face import Face
from .hash import HASH_PUMPKIN_SEEDS
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .crop import Crop, calculate_growth_chance, crop_neighbour_update_tick
from .pumpkin import Pumpkin
from .farmland import Farmland
from .dirt import Dirt
from .grass import Grass
from .block import is_air
from .cube.direction import directions


struct PumpkinSeeds(
    Block,
    Breakable,
    Compostable,
    Crop,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidRemovable,
    ModelledBlock,
    NeighbourUpdateTicker,
    RandomTicker,
):
    """A crop that grows pumpkin blocks."""

    comptime BASE_HASH: UInt64 = HASH_PUMPKIN_SEEDS
    """Go `hashPumpkinSeeds`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var growth: Int
    """The growth stage of the crop, 0 to 7 (Go `crop.Growth`)."""
    var direction: Face
    """The direction from the stem to the fruit."""

    def __init__(out self, *, growth: Int = 0, direction: Face = Face.DOWN):
        """Creates the block; omitted fields take Go zero values."""
        self.growth = growth
        self.direction = direction

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:pumpkin_stem",
            Properties()
            .with_int("facing_direction", Int32(Int(self.direction)))
            .with_int("growth", Int32(self.growth)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.growth) | UInt64(Int(self.direction)) << 8

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return PumpkinSeeds(
            growth=Int(hash & 0xFF), direction=Face(Int((hash >> 8) & 0x7))
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for i in range(8):
            for j in range(6):
                out.append(PumpkinSeeds(growth=i, direction=Face(j)))
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
        return EncodedItem("minecraft:pumpkin_seeds", 0)

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

    def growth_stage(self) -> Int:
        """Returns the growth stage (Go `GrowthStage`)."""
        return self.growth

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks unless on farmland, and forgets a pumpkin that is gone
        (Go `NeighbourUpdateTick`)."""
        if not tx.block_as[Farmland](pos.side(Face.DOWN)):
            break_block(self, pos, tx)
        elif self.direction != Face.DOWN:
            if not tx.block_as[Pumpkin](pos.side(self.direction)):
                var m = self.copy()
                m.direction = Face.DOWN
                tx.set_block(pos, m)

    def random_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Grows, then grows a pumpkin next to it (Go `RandomTick`)."""
        if not (
            tx.rand().float64() <= calculate_growth_chance(pos, tx)
            and tx.light(pos) >= 8
        ):
            return
        var m = self.copy()
        if m.growth < 7:
            m.growth += 1
            tx.set_block(pos, m)
            return
        var dirs = directions()
        for d in dirs:
            if tx.block_as[Pumpkin](pos.side(d.face())):
                return
        var direction = dirs[tx.rand().int_n(len(dirs))].face()
        var stem_pos = pos.side(direction)
        if is_air(tx, stem_pos):
            var below = stem_pos.side(Face.DOWN)
            if (
                tx.block_as[Farmland](below)
                or tx.block_as[Dirt](below)
                or tx.block_as[Grass](below)
            ):
                m.direction = direction
                tx.set_block(pos, m)
                tx.set_block(stem_pos, Pumpkin())
