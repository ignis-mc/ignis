"""`Beacon`, ported from Dragonfly `server/block/beacon.go`.

The effects a beacon gives are stored as their effect IDs (Go keeps the
`effect.LastingType` values). Players are not world entities in Ignis, so
the effects reach them as `LivingRequest`s on their player proxies, which
the server applies after the world tick.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from minecraft.nbt.tree import Tag, Tree

from ..internal.nbtconv.read import get_int32
from ..world.block import Block, LightDiffuser, LightEmitter, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_BEACON
from .model.solid import Solid as SolidModel
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace
from .block import (
    Activatable,
    UseContext,
)
from ..world.world import World, WorldTypes
from .cube.face import Face
from .cube.pos import Pos
from ..block.cube.bbox import BBox
from ..entity.effect import SECOND, Effect, new_ambient
from ..entity.effect.haste import Haste
from ..entity.effect.jump_boost import JumpBoost
from ..entity.effect.regeneration import Regeneration
from ..entity.effect.resistance import Resistance
from ..entity.effect.speed import Speed
from ..entity.effect.strength import Strength
from ..entity.living_request import REQUEST_EFFECT, LivingRequest
from ..world.block import TickerBlock


struct Beacon(
    Activatable,
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    LightDiffuser,
    LightEmitter,
    LiquidDisplacer,
    ModelledBlock,
    NBTer,
    TickerBlock,
):
    """A block that projects a light beam skyward, and can provide status effects such as Speed,
    Jump Boost, Haste, Regeneration, Resistance, or Strength to nearby players.
    """

    comptime BASE_HASH: UInt64 = HASH_BEACON
    """Go `hashBeacon`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var level: Int
    """The amount of pyramid levels the beacon is on, 0 to 4."""
    var primary: Int
    """The effect ID of the primary power; 0 for none (Go `Primary`)."""
    var secondary: Int
    """The effect ID of the secondary power; 0 for none (Go
    `Secondary`)."""

    def __init__(out self, *, level: Int = 0):
        """Creates the block; omitted fields take Go zero values."""
        self.level = level
        self.primary = 0
        self.secondary = 0

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return (
            self.hash() == other.hash()
            and self.level == other.level
            and self.primary == other.primary
            and self.secondary == other.secondary
        )

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `clicksAndSticks`).
        """
        return Instrument.CLICKS_AND_STICKS

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:beacon")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Beacon()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Beacon()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(3, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 15

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Opens the block's window (Go `Activate`)."""
        ctx.open_container = True
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:beacon", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        _ = tag.put_string(root, "id", "Beacon")
        _ = tag.put_int(root, "Levels", Int32(self.level))
        if beacon_effect_valid(self.primary) and self.primary != 0:
            _ = tag.put_int(root, "Primary", Int32(self.primary))
        if beacon_effect_valid(self.secondary) and self.secondary != 0:
            _ = tag.put_int(root, "Secondary", Int32(self.secondary))

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        var b = self.copy()
        b.level = Int(get_int32(tag, root, "Levels"))
        var p = Int(get_int32(tag, root, "Primary"))
        var s = Int(get_int32(tag, root, "Secondary"))
        b.primary = p if beacon_effect_valid(p) else 0
        b.secondary = s if beacon_effect_valid(s) else 0
        return b^

    def tick[
        T: WorldTypes
    ](self, current_tick: Int64, pos: Pos, mut tx: World[T]):
        """Every 4 s, counts the pyramid's levels and gives its effects to
        the players in range unless the beam is blocked (Go `Tick`)."""
        if current_tick % 80 != 0:
            return
        var b = self.copy()
        b.level = recalculate_level(pos, tx)
        if b.level != self.level:
            tx.set_block(pos, b)
        if b.level == 0:
            return
        if not obstructed(pos, tx):
            b._broadcast(pos, tx)

    def _broadcast[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        # Go `broadcastBeaconEffects`.
        var seconds = 9 + self.level * 2
        if self.level == 4:
            seconds -= 1
        var d = seconds * SECOND
        var primary = self.primary
        var secondary = 0
        if self.level == 1:
            if (
                primary == RESISTANCE_ID
                or primary == JUMP_BOOST_ID
                or primary == STRENGTH_ID
            ):
                primary = 0
        elif self.level == 2:
            if primary == STRENGTH_ID:
                primary = 0
        elif self.level >= 4:
            secondary = self.secondary
        var effects = List[Effect]()
        if primary != 0:
            if secondary == primary:
                effects.append(beacon_effect(primary, 2, d).value())
            else:
                effects.append(beacon_effect(primary, 1, d).value())
                if secondary != 0:
                    effects.append(beacon_effect(secondary, 1, d).value())
        if len(effects) == 0:
            return
        var r = Float64(10 + self.level * 10)
        var box = BBox.box(
            Float64(pos.x()) - r,
            -1e300,
            Float64(pos.z()) - r,
            Float64(pos.x()) + r,
            1e300,
            Float64(pos.z()) + r,
        )
        for id in tx.entities_within(box):
            var req = LivingRequest(REQUEST_EFFECT)
            req.effects = effects.copy()
            _ = tx.living_request(id, req^)

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)


comptime SPEED_ID = 1
"""Speed's effect ID."""
comptime HASTE_ID = 3
"""Haste's effect ID."""
comptime STRENGTH_ID = 5
"""Strength's effect ID."""
comptime JUMP_BOOST_ID = 8
"""Jump Boost's effect ID."""
comptime REGENERATION_ID = 10
"""Regeneration's effect ID."""
comptime RESISTANCE_ID = 11
"""Resistance's effect ID."""


def beacon_effect_valid(id: Int) -> Bool:
    """Reports whether an ID is a beacon power or 0."""
    return (
        id == 0
        or id == SPEED_ID
        or id == HASTE_ID
        or id == STRENGTH_ID
        or id == JUMP_BOOST_ID
        or id == REGENERATION_ID
        or id == RESISTANCE_ID
    )


def beacon_effect(id: Int, lvl: Int, d: Int) -> Optional[Effect]:
    """Returns an ambient effect of a beacon power (Go `NewAmbient`)."""
    if id == SPEED_ID:
        return new_ambient(Speed(), lvl, d)
    if id == HASTE_ID:
        return new_ambient(Haste(), lvl, d)
    if id == STRENGTH_ID:
        return new_ambient(Strength(), lvl, d)
    if id == JUMP_BOOST_ID:
        return new_ambient(JumpBoost(), lvl, d)
    if id == REGENERATION_ID:
        return new_ambient(Regeneration(), lvl, d)
    if id == RESISTANCE_ID:
        return new_ambient(Resistance(), lvl, d)
    return None


def recalculate_level[T: WorldTypes](pos: Pos, mut tx: World[T]) -> Int:
    """Counts the full pyramid layers under a beacon (Go
    `recalculateLevel`)."""
    var br = tx.block_registry()
    var lvl = 0
    var iter = 1
    for y in range(pos.y() - 1, pos.y() - 5, -1):
        for x in range(pos.x() - iter, pos.x() + iter + 1):
            for z in range(pos.z() - iter, pos.z() + iter + 1):
                var rid = tx.block(Pos(x, y, z))
                if not T.Blocks.powers_beacon(
                    br[].kind(rid), br[].state_hash(rid)
                ):
                    return lvl
        iter += 1
        lvl += 1
    return lvl


def obstructed[T: WorldTypes](pos: Pos, mut tx: World[T]) -> Bool:
    """Reports whether something blocks the beam (Go `obstructed`)."""
    if tx.sky_light(pos.side(Face.UP)) == 15:
        return False
    return tx.highest_light_blocker(pos.x(), pos.z()) > pos.y()
