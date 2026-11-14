"""`Candle`, ported from Dragonfly `server/block/candle.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): UseOnBlock, Splash, HasLiquidDrops, Model and the drops.
"""

from ..item.enchantment import FIRE_ASPECT_ID
from ..world.sound.block import Ignite
from .block import Activatable, UseContext


from ..item.optional_colour import OptionalColour, optional_colours
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
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    break_block,
    break_block_no_drops,
    new_break_info,
)
from .hash import AnyBlock, HASH_CANDLE
from .model.candle import Candle as CandleModel
from .liquid import source_water_can_displace
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import face_solid_at, is_air
from .water import Water
from ..world.sound.block import FireExtinguish


struct Candle(
    Activatable,
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
    """A dyeable block that emits light when lit with a flint and steel."""

    comptime BASE_HASH: UInt64 = HASH_CANDLE
    """Go `hashCandle`."""
    comptime ModelType = CandleModel
    """The model type (Go `Model`)."""

    var colour: OptionalColour
    """The colour of the candle, or none."""
    var additional_candles: Int
    """The number of additional candles in the block, 0 to 3."""
    var lit: Bool
    """Whether the candles are lit."""

    def __init__(
        out self,
        *,
        colour: OptionalColour = OptionalColour.NONE,
        additional_candles: Int = 0,
        lit: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.colour = colour
        self.additional_candles = additional_candles
        self.lit = lit

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Lights the candle with a fire aspect item (Go `Activate`)."""
        if ctx.held.enchantment(FIRE_ASPECT_ID):
            _ = self.ignite(pos, tx)
            ctx.damage_item(1)
            return True
        return False

    def ignite[T: WorldTypes](self, pos: Pos, mut tx: World[T]) -> Bool:
        """Lights the candle (Go `Ignite`)."""
        if tx.liquid(pos) or self.lit:
            return False
        var c = self
        c.lit = True
        tx.set_block(pos, c)
        tx.play_sound(pos.vec3(), Ignite())
        return True

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:" + self.colour.prepend("candle"),
            Properties()
            .with_int("candles", Int32(self.additional_candles))
            .with_bool("lit", self.lit),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.colour.uint8())
            | UInt64(self.additional_candles) << 5
            | (UInt64(1) if self.lit else UInt64(0)) << 13
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Candle(
            colour=OptionalColour(Int(hash & 0x1F)),
            additional_candles=Int((hash >> 5) & 0xFF),
            lit=(hash >> 13) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for i in range(4):
            for c in optional_colours():
                out.append(Candle(colour=c, additional_candles=i))
                out.append(Candle(colour=c, additional_candles=i, lit=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.1, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        if not self.lit:
            return 0
        return UInt8((self.additional_candles + 1) * 3)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> CandleModel:
        """Returns the model of the block (Go `Model`)."""
        return CandleModel(count=self.additional_candles + 1)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:" + self.colour.prepend("candle"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for c in optional_colours():
            out.append(Self(colour=c))
        return out^

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks without a solid face below; water puts it out (Go
        `NeighbourUpdateTick`)."""
        if not face_solid_at(tx, pos.side(Face.DOWN), Face.UP):
            break_block(self, pos, tx)
            return
        var l = tx.liquid(pos)
        var br = tx.block_registry()
        if l and br[].is_block[Water](l.value()) and self.lit:
            var c = self.copy()
            c.lit = False
            tx.set_block(pos, c)
            tx.play_sound(pos.vec3_centre(), FireExtinguish())
