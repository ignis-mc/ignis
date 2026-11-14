"""`Cake`, ported from Dragonfly `server/block/cake.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

Ignis players have no hunger yet: eating sets the use context's food and
saturation, which the server does not apply.

TODO(world-runtime): UseOnBlock, Model, HasLiquidDrops and the drops.
"""

from ..item.enchantment import FIRE_ASPECT_ID
from ..item.flint_and_steel import FlintAndSteel
from ..item.stack import Stack
from ..mgl64 import Vec3
from ..world.sound.block import Ignite
from ..world.sound.entity import Burp
from ..world.sound.item import ItemUseOn
from .air import Air
from .block import Activatable, UseContext
from .candle import Candle


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
    NEVER_HARVESTABLE,
    NOTHING_EFFECTIVE,
    break_block,
    break_block_no_drops,
    new_break_info,
)
from .hash import AnyBlock, HASH_CAKE
from .model.cake import Cake as CakeModel
from .liquid import source_water_can_displace
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import face_solid_at, is_air
from .water import Water
from ..world.sound.block import FireExtinguish


struct Cake(
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
    """An edible block."""

    comptime BASE_HASH: UInt64 = HASH_CAKE
    """Go `hashCake`."""
    comptime ModelType = CakeModel
    """The model type (Go `Model`)."""

    var bites: Int
    """The number of bites taken out of the cake, 0 to 6."""
    var candle: Bool
    """Whether a candle is placed on the cake."""
    var candle_colour: OptionalColour
    """The colour of the candle on the cake."""
    var candle_lit: Bool
    """Whether the candle on the cake is lit."""

    def __init__(
        out self,
        *,
        bites: Int = 0,
        candle: Bool = False,
        candle_colour: OptionalColour = OptionalColour.NONE,
        candle_lit: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.bites = bites
        self.candle = candle
        self.candle_colour = candle_colour
        self.candle_lit = candle_lit

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Puts a candle on the cake, lights or snuffs it, or eats a bite (Go
        `Activate`)."""
        var c = self
        if c.bites == 0 and not c.candle:
            if case .Some(candle) = ctx.held.item_as[Candle]():
                c.candle = True
                c.candle_colour = candle.colour
                tx.set_block(pos, c)
                tx.play_sound(pos.vec3_centre(), ItemUseOn(block=AnyBlock(c)))
                ctx.subtract_from_count(1)
                return True
        if ctx.held.enchantment(FIRE_ASPECT_ID):
            _ = c.ignite(pos, tx)
            ctx.damage_item(1)
            return True
        if ctx.held.item_as[FlintAndSteel]():
            return False
        if c.candle and c.candle_lit and face == Face.UP and ctx.held.empty():
            c.candle_lit = False
            tx.set_block(pos, c)
            return True
        # Go: the user implements Saturate (every Ignis user is a player).
        if c.candle:
            tx.drop_item(
                pos.vec3_centre(), Stack(Candle(colour=c.candle_colour), 1)
            )
            c.candle = False
            c.candle_lit = False
            c.candle_colour = OptionalColour(0)
        ctx.food = 2
        ctx.saturation = 0.4
        tx.play_sound(ctx.user_pos.add(Vec3(0, 1.5, 0)), Burp())
        c.bites += 1
        if c.bites > 6:
            tx.set_block(pos, Air())
            return True
        tx.set_block(pos, c)
        return True

    def ignite[T: WorldTypes](self, pos: Pos, mut tx: World[T]) -> Bool:
        """Lights the candle on the cake (Go `Ignite`)."""
        if not self.candle or self.candle_lit:
            return False
        if tx.liquid(pos):
            return False
        var c = self
        c.candle_lit = True
        tx.set_block(pos, c)
        tx.play_sound(pos.vec3(), Ignite())
        return True

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.candle:
            return BlockState(
                "minecraft:" + self.candle_colour.prepend("candle_cake"),
                Properties().with_bool("lit", self.candle_lit),
            )
        return BlockState(
            "minecraft:cake",
            Properties().with_int("bite_counter", Int32(self.bites)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.bites)
            | (UInt64(1) if self.candle else UInt64(0)) << 8
            | UInt64(self.candle_colour.uint8()) << 9
            | (UInt64(1) if self.candle_lit else UInt64(0)) << 14
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Cake(
            bites=Int(hash & 0xFF),
            candle=(hash >> 8) & 0x1 != 0,
            candle_colour=OptionalColour(Int((hash >> 9) & 0x1F)),
            candle_lit=(hash >> 14) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for bites in range(7):
            out.append(Cake(bites=bites))
        for c in optional_colours():
            out.append(Cake(candle_colour=c, candle=True))
            out.append(Cake(candle_colour=c, candle=True, candle_lit=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        if self.candle:
            return new_break_info(0.5, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)
        return new_break_info(0.5, NEVER_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 3 if self.candle and self.candle_lit else 0

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> CakeModel:
        """Returns the model of the block (Go `Model`)."""
        return CakeModel(bites=self.bites)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.candle:
            var name = self.candle_colour.prepend("candle_cake")
            return EncodedItem("minecraft:" + name, 0)
        return EncodedItem("minecraft:cake", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks over air; water puts its candle out (Go
        `NeighbourUpdateTick`)."""
        if is_air(tx, pos.side(Face.DOWN)):
            break_block(self, pos, tx)
            return
        var l = tx.liquid(pos)
        var br = tx.block_registry()
        if (
            l
            and br[].is_block[Water](l.value())
            and self.candle
            and self.candle_lit
        ):
            var c = self.copy()
            c.candle_lit = False
            tx.set_block(pos, c)
            tx.play_sound(pos.vec3_centre(), FireExtinguish())
