"""`Composter`, ported from Dragonfly `server/block/composter.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): InsertItem, ExtractItem (hoppers), FlammabilityInfo, the
break handler dropping bone meal and the drops.
"""

from ..item.bone_meal import BoneMeal
from ..item.register import VanillaBlockItems, VanillaItems
from ..item.stack import Stack
from ..world.block import ScheduledTicker
from ..world.particle.block import BoneMeal as BoneMealParticle
from ..world.sound.block import (
    ComposterEmpty,
    ComposterFill,
    ComposterFillLayer,
    ComposterReady,
)
from ..world.world import World, WorldTypes
from .block import Activatable, UseContext
from .cube.face import Face
from .cube.pos import Pos


from ..world.sound.instrument import Instrument
from .block import Instrumented

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
from .hash import HASH_COMPOSTER
from .model.composter import Composter as ComposterModel
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct Composter(
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
    ScheduledTicker,
):
    """A block that turns organic items into bone meal."""

    comptime BASE_HASH: UInt64 = HASH_COMPOSTER
    """Go `hashComposter`."""
    comptime ModelType = ComposterModel
    """The model type (Go `Model`)."""

    var level: Int
    """How full the composter is, 0 to 8."""

    def __init__(out self, *, level: Int = 0):
        """Creates the block; omitted fields take Go zero values."""
        self.level = level

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bass`)."""
        return Instrument.BASS

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Empties a full composter or composts the held item (Go
        `Activate`)."""
        if self.level >= 7:
            if self.level == 8:
                var c = self
                c.level = 0
                tx.set_block(pos, c)
                tx.drop_item(
                    pos.side(Face.UP).vec3_middle(), Stack(BoneMeal(), 1)
                )
                tx.play_sound(pos.vec3(), ComposterEmpty())
                # The bone meal was collected, so the held item is not used.
                return True
            return False
        if self.fill(ctx.held, pos, tx):
            ctx.subtract_from_count(1)
            return True
        return False

    def fill[
        T: WorldTypes
    ](self, it: Stack, pos: Pos, mut tx: World[T]) -> Bool:
        """Composts an item, adding a layer with its compost chance (Go
        `fill`)."""
        if it.empty():
            return False
        var item = it.item().value()
        var chance: Optional[Float64]
        if item.block:
            chance = VanillaBlockItems.compost_chance(item.kind, item.hash)
        else:
            chance = VanillaItems.compost_chance(item.kind, item.hash)
        if not chance:
            return False
        tx.add_particle(pos.vec3(), BoneMealParticle())
        if tx.global_rand().float64() > chance.value():
            tx.play_sound(pos.vec3(), ComposterFill())
            return True
        var c = self
        c.level += 1
        tx.set_block(pos, c)
        tx.play_sound(pos.vec3(), ComposterFillLayer())
        if c.level == 7:
            tx.schedule_block_update(pos, c, 1000)
        return True

    def scheduled_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Turns a level 7 composter into a full one (Go `ScheduledTick`)."""
        if self.level == 7:
            var c = self
            c.level = 8
            tx.set_block(pos, c)
            tx.play_sound(pos.vec3(), ComposterReady())

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:composter",
            Properties().with_int("composter_fill_level", Int32(self.level)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.level)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Composter(level=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for level in range(9):
            out.append(Composter(level=level))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.6, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> ComposterModel:
        """Returns the model of the block (Go `Model`)."""
        return ComposterModel(level=self.level)

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:composter", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
