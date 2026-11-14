"""`Water`, ported from Dragonfly `server/block/water.go`.

`replaceable_by` asks `VanillaBlocks` about the other block's type (Go type
asserts it); `Replaceable` has no world to ask.

TODO(world-runtime): EntityInside, FillBottle, PistonBreakable.
"""

from std.os import abort

from ..world.block import (
    Block,
    LightDiffuser,
    Liquid,
    NeighbourUpdateTicker,
    ScheduledTicker,
)
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.sound.block import Fizz
from ..world.tx import Context
from ..world.world import World, WorldTypes
from .block import Replaceable
from .break_info import drop_item, tool_none_drops
from .cobblestone import Cobblestone
from .cube.face import Face
from .cube.pos import Pos
from .hash import HASH_WATER, AnyBlock
from .lava import Lava
from .liquid import (
    LiquidRemovable,
    can_flow_into,
    liquid_replaceable_by,
    tick_liquid,
)
from .model.empty import Empty as EmptyModel
from .register import VanillaBlocks
from .stone import Stone


struct Water(
    Block,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    Liquid,
    LiquidRemovable,
    ModelledBlock,
    NeighbourUpdateTicker,
    Replaceable,
    ScheduledTicker,
):
    """A natural fluid that generates abundantly in the world."""

    comptime BASE_HASH: UInt64 = HASH_WATER
    """Go `hashWater`."""
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
            abort("invalid water depth, must be between 1 and 8")
        var v = Int32(8 - self.depth)
        if self.falling:
            v += 8
        var name = (
            "minecraft:water" if self.still else "minecraft:flowing_water"
        )
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
        return Water(
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
                out.append(Water(still=flags[0], falling=flags[1], depth=depth))
        return out^

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 2

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def replaceable_by(self, b: AnyBlock) -> Bool:
        """Reports whether `b` may replace the water (Go `ReplaceableBy`)."""
        return liquid_replaceable_by[VanillaBlocks](b)

    def liquid_depth(self) -> Int:
        """Returns the depth of the water (Go `LiquidDepth`)."""
        return self.depth

    def spread_decay(self) -> Int:
        """Returns 1 (Go `SpreadDecay`)."""
        return 1

    def with_depth(self, depth: Int, falling: Bool) -> Self:
        """Returns flowing water with the depth passed (Go `WithDepth`)."""
        return Water(still=False, depth=depth, falling=falling)

    def liquid_falling(self) -> Bool:
        """Returns `falling` (Go `LiquidFalling`)."""
        return self.falling

    def blast_resistance(self) -> Float64:
        """Returns 100 (Go `BlastResistance`)."""
        return 100

    def liquid_type(self) -> StaticString:
        """Returns "water" (Go `LiquidType`)."""
        return "water"

    def has_liquid_drops(self) -> Bool:
        """Returns False (Go `HasLiquidDrops`)."""
        return False

    def liquid_remove_block[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], removed: UInt32):
        """Drops the items of the removed block if it has liquid drops (Go
        `LiquidRemoveBlock`)."""
        var br = tx.block_registry()
        var r = T.Blocks.liquid_removable(
            br[].kind(removed), br[].state_hash(removed)
        )
        if not r or not r.value():
            return
        for ref d in tool_none_drops(removed, tx):
            drop_item(tx, d, pos.vec3_centre())

    def scheduled_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Forms new sources between two sources, then flows (Go
        `ScheduledTick`)."""
        if self.depth == 7:
            var count = 0
            var br = tx.block_registry()
            for neighbour in pos.neighbours(tx.range()):
                if neighbour.y() == pos.y():
                    if case .Some(rid) = tx.liquid(neighbour):
                        if case .Some(w) = br[].block[Water](rid):
                            if w.depth == 8 and not w.falling:
                                count += 1
            if count >= 2:
                if not can_flow_into(self, tx, pos.side(Face.DOWN), True):
                    # Only form a source if the water below, if any, is not
                    # falling.
                    var res = Water(depth=8, still=True)
                    var ctx = Context()
                    tx.handle_liquid_flow(
                        ctx, pos, pos, AnyBlock(res), AnyBlock(self)
                    )
                    if ctx.cancelled():
                        return
                    tx.set_liquid(pos, res)
        tick_liquid(self, pos, tx)

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Evaporates in dimensions where water does, else schedules a flow
        (Go `NeighbourUpdateTick`)."""
        if tx.dimension().water_evaporates():
            # Particles are spawned client-side.
            tx.remove_liquid(pos)
            return
        tx.schedule_block_update(pos, self, 250)

    def harden[
        T: WorldTypes
    ](self, pos: Pos, mut tx: World[T], flown_into_by: Optional[Pos]) -> Bool:
        """Turns into stone under lava, or turns lava flowing in into
        cobblestone (Go `Harden`)."""
        if not flown_into_by:
            return False
        var by = flown_into_by.value()
        if case .Some(lava) = tx.block_as[Lava](pos.side(Face.UP)):
            var ctx = Context()
            tx.handle_liquid_harden(
                ctx, pos, AnyBlock(self), AnyBlock(lava), AnyBlock(Stone())
            )
            if ctx.cancelled():
                return False
            tx.set_block(pos, Stone())
            tx.play_sound(pos.vec3_centre(), Fizz())
            return True
        elif case .Some(lava) = tx.block_as[Lava](by):
            var ctx = Context()
            tx.handle_liquid_harden(
                ctx,
                pos,
                AnyBlock(self),
                AnyBlock(lava),
                AnyBlock(Cobblestone()),
            )
            if ctx.cancelled():
                return False
            tx.set_block(by, Cobblestone())
            tx.play_sound(pos.vec3_centre(), Fizz())
            return True
        return False
