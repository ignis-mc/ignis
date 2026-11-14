"""The block particles, ported from Dragonfly `server/world/particle/block.go`.
"""

from ...block.cube.face import Face
from ...block.cube.pos import Pos
from ...block.hash import AnyBlock
from ...internal.color import RGBA
from ..block_registry import UNKNOWN_KIND
from ..sound.instrument import Instrument
from . import Particle


struct Flame(ImplicitlyCopyable, Particle):
    """A particle shown around torches. It can have any colour specified with
    the Colour field. If the colour is not specified, it will default to
    the normal flame particle (Go `particle.Flame`)."""

    comptime PARTICLE_ID: Int = 1
    """The particle ID of `Flame`."""

    var colour: RGBA
    """Colour is the colour of the Flame particle."""

    def __init__(out self, *, colour: RGBA = RGBA()):
        """Creates the value; omitted fields take Go zero values."""
        self.colour = colour


struct Dust(ImplicitlyCopyable, Particle):
    """A particle shown for redstone. It can have any colour specified with the
    Colour field. If the colour is not specified, it will default to
    black (Go `particle.Dust`)."""

    comptime PARTICLE_ID: Int = 2
    """The particle ID of `Dust`."""

    var colour: RGBA
    """Colour is the colour of the Dust particle."""

    def __init__(out self, *, colour: RGBA = RGBA()):
        """Creates the value; omitted fields take Go zero values."""
        self.colour = colour


struct BlockBreak(ImplicitlyCopyable, Particle):
    """A particle sent when a block is broken. It represents a bunch of
    particles that are textured like the block that the particle holds
    (Go `particle.BlockBreak`)."""

    comptime PARTICLE_ID: Int = 3
    """The particle ID of `BlockBreak`."""

    var block: AnyBlock
    """Block is the block of which particles should be shown. The particles
    will change depending on what block is held."""

    def __init__(
        out self, *, block: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0)
    ):
        """Creates the value; omitted fields take Go zero values."""
        self.block = block


struct PunchBlock(ImplicitlyCopyable, Particle):
    """A particle shown when a player is punching a block. It shows particles
    of a specific block type at a particular face of a block (Go
    `particle.PunchBlock`)."""

    comptime PARTICLE_ID: Int = 4
    """The particle ID of `PunchBlock`."""

    var block: AnyBlock
    """Block is the block of which particles should be shown. The particles
    will change depending on what block is punched."""
    var face: Face
    """Face is the face of the block that was punched. It is here that the
    particles will be shown."""

    def __init__(
        out self,
        *,
        block: AnyBlock = AnyBlock(kind=UNKNOWN_KIND, state=0),
        face: Face = Face.DOWN,
    ):
        """Creates the value; omitted fields take Go zero values."""
        self.block = block
        self.face = face


@fieldwise_init
struct BlockForceField(ImplicitlyCopyable, Particle):
    """A particle that shows up as a block that turns invisible from an opaque
    black colour (Go `particle.BlockForceField`)."""

    comptime PARTICLE_ID: Int = 5
    """The particle ID of `BlockForceField`."""


struct BoneMeal(ImplicitlyCopyable, Particle):
    """A particle that shows up on bone meal usage (Go `particle.BoneMeal`)."""

    comptime PARTICLE_ID: Int = 6
    """The particle ID of `BoneMeal`."""

    var area: Bool
    """Area specifies whether the particle effect should be for area. If
    false, a small burst is used for minor growth. If true, a large
    burst is used for significant growth."""

    def __init__(out self, *, area: Bool = False):
        """Creates the value; omitted fields take Go zero values."""
        self.area = area


struct Note(ImplicitlyCopyable, Particle):
    """A particle that shows up on note block interactions (Go
    `particle.Note`)."""

    comptime PARTICLE_ID: Int = 7
    """The particle ID of `Note`."""

    var instrument: Instrument
    """Instrument is the instrument of the note block."""
    var pitch: Int
    """Pitch is the pitch of the note."""

    def __init__(
        out self, *, instrument: Instrument = Instrument.PIANO, pitch: Int = 0
    ):
        """Creates the value; omitted fields take Go zero values."""
        self.instrument = instrument
        self.pitch = pitch


struct DragonEggTeleport(ImplicitlyCopyable, Particle):
    """A particle that shows up when a dragon egg teleports (Go
    `particle.DragonEggTeleport`)."""

    comptime PARTICLE_ID: Int = 8
    """The particle ID of `DragonEggTeleport`."""

    var diff: Pos
    """Diff is a Position with the values being the difference from the
    original position to the new position."""

    def __init__(out self, *, diff: Pos = Pos(0, 0, 0)):
        """Creates the value; omitted fields take Go zero values."""
        self.diff = diff


@fieldwise_init
struct Evaporate(ImplicitlyCopyable, Particle):
    """A particle that shows up when a water block evaporates (Go
    `particle.Evaporate`)."""

    comptime PARTICLE_ID: Int = 9
    """The particle ID of `Evaporate`."""


@fieldwise_init
struct WaterDrip(ImplicitlyCopyable, Particle):
    """A particle that shows up when there is water above a block and it looks
    like a dripping effect (Go `particle.WaterDrip`)."""

    comptime PARTICLE_ID: Int = 10
    """The particle ID of `WaterDrip`."""


@fieldwise_init
struct LavaDrip(ImplicitlyCopyable, Particle):
    """A particle that shows up when there is lava above a block and it looks
    like a dripping effect (Go `particle.LavaDrip`)."""

    comptime PARTICLE_ID: Int = 11
    """The particle ID of `LavaDrip`."""


@fieldwise_init
struct Lava(ImplicitlyCopyable, Particle):
    """A particle that shows up randomly above lava (Go `particle.Lava`)."""

    comptime PARTICLE_ID: Int = 12
    """The particle ID of `Lava`."""


@fieldwise_init
struct DustPlume(ImplicitlyCopyable, Particle):
    """A particle that shows up when an item is successfully inserted into a
    decorated pot (Go `particle.DustPlume`)."""

    comptime PARTICLE_ID: Int = 13
    """The particle ID of `DustPlume`."""
