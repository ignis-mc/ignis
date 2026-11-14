"""`Lava`, ported from Dragonfly `server/block/lava.go`.

`replaceable_by` asks `VanillaBlocks` about the other block's type (Go type
asserts it); `Replaceable` has no world to ask.

TODO(world-runtime): EntityInside, LavaDamageSource.
"""

from std.os import abort

from ..world.block import (
    Block,
    LightDiffuser,
    LightEmitter,
    Liquid,
    NeighbourUpdateTicker,
    ScheduledTicker,
)
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.sound.block import Fizz
from ..world.tx import Context
from ..world.world import World, WorldTypes
from .basalt import Basalt
from .block import Replaceable
from .blue_ice import BlueIce
from .cobblestone import Cobblestone
from .cube.face import Face
from .cube.pos import Pos
from .hash import HASH_LAVA, AnyBlock
from .liquid import LiquidRemovable, liquid_replaceable_by, tick_liquid
from .model.empty import Empty as EmptyModel
from .obsidian import Obsidian
from .register import VanillaBlocks
from .soul_soil import SoulSoil
from .water import Water


struct Lava(
    Block,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    LightEmitter,
    Liquid,
    LiquidRemovable,
    ModelledBlock,
    NeighbourUpdateTicker,
    Replaceable,
    ScheduledTicker,
):
    """A light-emitting fluid block that causes fire damage."""

    comptime BASE_HASH: UInt64 = HASH_LAVA
    """Go `hashLava`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var still: Bool
    """Whether the liquid is still, a source block that does not flow."""
    var depth: Int
    """The depth of the liquid, 1 to 8."""
    var falling: Bool
    """Whether the liquid falls down."""

    def __init__(
        out self, *, still: Bool = False, depth: Int = 8, falling: Bool = False
    ):
        """Creates the block; `depth` defaults to 8, a full block."""
        self.still = still
        self.depth = depth
        self.falling = falling

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.depth < 1 or self.depth > 8:
            abort("invalid lava depth, must be between 1 and 8")
        var v = Int32(8 - self.depth)
        if self.falling:
            v += 8
        var name = "minecraft:lava" if self.still else "minecraft:flowing_lava"
        return BlockState(name, Properties().with_int("liquid_depth", v))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            (UInt64(1) if self.still else UInt64(0))
            | UInt64(self.depth) << 1
            | (UInt64(1) if self.falling else UInt64(0)) << 9
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Lava(
            still=hash & 0x1 != 0,
            depth=Int((hash >> 1) & 0xFF),
            falling=(hash >> 9) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for flags in [
            (True, True),
            (True, False),
            (False, False),
            (False, True),
        ]:
            for depth in range(8, 0, -1):
                out.append(Lava(still=flags[0], falling=flags[1], depth=depth))
        return out^

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 15

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 2

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def replaceable_by(self, b: AnyBlock) -> Bool:
        """Reports whether `b` may replace the lava (Go `ReplaceableBy`)."""
        return liquid_replaceable_by[VanillaBlocks](b)

    def liquid_depth(self) -> Int:
        """Returns the depth of the lava (Go `LiquidDepth`)."""
        return self.depth

    def spread_decay(self) -> Int:
        """Returns 2 (Go `SpreadDecay`)."""
        return 2

    def with_depth(self, depth: Int, falling: Bool) -> Self:
        """Returns flowing lava with the depth passed (Go `WithDepth`)."""
        return Lava(still=False, depth=depth, falling=falling)

    def liquid_falling(self) -> Bool:
        """Returns `falling` (Go `LiquidFalling`)."""
        return self.falling

    def blast_resistance(self) -> Float64:
        """Returns 100 (Go `BlastResistance`)."""
        return 100

    def liquid_type(self) -> StaticString:
        """Returns "lava" (Go `LiquidType`)."""
        return "lava"

    def has_liquid_drops(self) -> Bool:
        """Returns False (Go `HasLiquidDrops`)."""
        return False

    def liquid_remove_block[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], removed: UInt32):
        """Plays a fizz where the removed block was (Go
        `LiquidRemoveBlock`)."""
        tx.play_sound(pos.vec3_centre(), Fizz())

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Hardens next to water, else schedules a flow (Go
        `NeighbourUpdateTick`)."""
        if not self.harden(pos, tx, None):
            tx.schedule_block_update(
                pos, self, tx.dimension().lava_spread_duration_ms()
            )

    def scheduled_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Hardens next to water, else flows (Go `ScheduledTick`)."""
        if not self.harden(pos, tx, None):
            tick_liquid(self, pos, tx)

    def harden[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], flown_into_by: Optional[Pos]) -> Bool:
        """Turns into obsidian (a source) or cobblestone next to water, or
        basalt over soul soil next to blue ice (Go `Harden`)."""
        if not flown_into_by:
            var water: Optional[AnyBlock] = None
            var b: Optional[AnyBlock] = None
            var soul_soil_found = Bool(
                tx.block_as[SoulSoil](pos.side(Face.DOWN))
            )
            for neighbour in pos.neighbours(tx.range()):
                if b or neighbour.y() == pos.y() - 1:
                    continue
                if tx.block_as[BlueIce](neighbour):
                    if soul_soil_found:
                        b = AnyBlock(Basalt())
                    continue
                if case .Some(w) = tx.block_as[Water](neighbour):
                    water = AnyBlock(w)
                    if self.depth == 8 and not self.falling:
                        b = AnyBlock(Obsidian())
                        continue
                    b = AnyBlock(Cobblestone())
            if case .Some(nb) = b:
                var ctx = Context()
                # Go passes a nil water block for basalt.
                var other = water.or_else(AnyBlock(kind=UInt64.MAX, state=0))
                tx.handle_liquid_harden(ctx, pos, AnyBlock(self), other, nb)
                if ctx.cancelled():
                    return False
                tx.play_sound(pos.vec3_centre(), Fizz())
                var br = tx.block_registry()
                tx.set_block_runtime_id(
                    pos, br[].runtime_id_of(nb.kind, nb.state).value()
                )
                return True
            return False
        var w = tx.block_as[Water](flown_into_by.value())
        if not w:
            return False
        var nb: AnyBlock
        if self.depth == 8 and not self.falling:
            nb = AnyBlock(Obsidian())
        else:
            nb = AnyBlock(Cobblestone())
        var ctx = Context()
        tx.handle_liquid_harden(
            ctx, pos, AnyBlock(self), AnyBlock(w.value()), nb
        )
        if ctx.cancelled():
            return False
        var br = tx.block_registry()
        tx.set_block_runtime_id(
            pos, br[].runtime_id_of(nb.kind, nb.state).value()
        )
        tx.play_sound(pos.vec3_centre(), Fizz())
        return True
