"""`RedstoneOre`, ported from Dragonfly `server/block/redstone_ore.go`.

TODO(world-runtime): Punch, EntityStepOn and the drops.
"""

from ..internal.color import RGBA
from ..mgl64 import Vec3
from ..world.particle.block import Dust
from .block import Activatable, UseContext
from .cube.face import Face
from .cube.pos import Pos


from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
from ..world.block import Block, LightEmitter, RandomTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    HARVEST_LEVEL_IRON,
    PICKAXE_EFFECTIVE,
    new_break_info,
    pickaxe_harvestable_from,
)
from .hash import HASH_REDSTONE_ORE
from .model.solid import Solid as SolidModel
from .ore_type import OreType, ore_types
from .redstone_wire import RedstoneWire
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face


struct RedstoneOre(
    Activatable,
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    LightEmitter,
    ModelledBlock,
    RandomTicker,
    Smeltable,
):
    """A common ore that lights up when touched."""

    comptime BASE_HASH: UInt64 = HASH_REDSTONE_ORE
    """Go `hashRedstoneOre`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var type: OreType
    """The rock the ore is embedded in."""
    var lit: Bool
    """Whether the ore is lit up."""

    def __init__(out self, *, type: OreType = OreType.STONE, lit: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.type = type
        self.lit = lit

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def activate[
        T: WorldTypes
    ](
        self, pos: Pos, face: Face, mut tx: World[T], mut ctx: UseContext
    ) -> Bool:
        """Lights up unless the user sneaks; never counts as used (Go
        `Activate`)."""
        if ctx.sneaking:
            return False
        self.light(pos, tx)
        return False

    def light[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Emits particles and starts glowing (Go `light`)."""
        self.emit_particles(pos, tx)
        if self.lit:
            return
        var r = self
        r.lit = True
        tx.set_block(pos, r)

    def emit_particles[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Emits the red particles of disturbed redstone ore (Go
        `emitParticles`)."""
        for _ in range(5):
            var offset = redstone_ore_particle_offset(tx)
            tx.add_particle(
                pos.vec3().add(offset),
                Dust(colour=REDSTONE_ORE_PARTICLE_COLOUR),
            )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var lit = "lit_" if self.lit else ""
        return BlockState(
            String(t"minecraft:{lit}{self.type.prefix()}redstone_ore")
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.type.uint8())
            | (UInt64(1) if self.lit else UInt64(0)) << 1
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return RedstoneOre(
            type=OreType(Int(hash & 0x1)), lit=(hash >> 1) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for t in ore_types():
            out.append(RedstoneOre(type=t))
            out.append(RedstoneOre(type=t, lit=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return (
            new_break_info(
                self.type.hardness(),
                pickaxe_harvestable_from(HARVEST_LEVEL_IRON),
                PICKAXE_EFFECTIVE,
            )
            .with_xp_drop_range(1, 5)
            .with_blast_resistance(3)
        )

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 9 if self.lit else 0

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(
            String(t"minecraft:{self.type.prefix()}redstone_ore"), 0
        )

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        return SmeltInfo(Stack(RedstoneWire(), 1), 0.7, ores=True)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in ore_types():
            out.append(RedstoneOre(type=v))
        return out^

    def random_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Stops glowing (Go `RandomTick`, `fade`)."""
        if not self.lit:
            return
        var r = self.copy()
        r.lit = False
        tx.set_block(pos, r)


comptime REDSTONE_ORE_PARTICLE_COLOUR = RGBA(255, 0, 0, 255)
"""The colour of redstone ore particles (Go `redstoneOreParticleColour`)."""


def redstone_ore_particle_offset[T: WorldTypes](mut tx: World[T]) -> Vec3:
    """Returns a random offset on or just outside one face of the block (Go
    `redstoneOreParticleOffset`, drawing from the global source)."""
    var x = tx.global_rand().float64()
    var y = tx.global_rand().float64()
    var z = tx.global_rand().float64()
    comptime edge = 0.05
    var side = tx.global_rand().int_n(6)
    if side == 0:
        x = -edge
    elif side == 1:
        x = 1 + edge
    elif side == 2:
        y = -edge
    elif side == 3:
        y = 1 + edge
    elif side == 4:
        z = -edge
    elif side == 5:
        z = 1 + edge
    return Vec3(x, y, z)
