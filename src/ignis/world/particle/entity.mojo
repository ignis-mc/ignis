"""The entity particles, ported from Dragonfly `server/world/particle/entity.go`.
"""

from ...internal.color import RGBA
from . import Particle


@fieldwise_init
struct HugeExplosion(ImplicitlyCopyable, Particle):
    """A particle shown when TNT or a creeper explodes (Go
    `particle.HugeExplosion`)."""

    comptime PARTICLE_ID: Int = 14
    """The particle ID of `HugeExplosion`."""


@fieldwise_init
struct EndermanTeleport(ImplicitlyCopyable, Particle):
    """A particle that shows up when an enderman teleports (Go
    `particle.EndermanTeleport`)."""

    comptime PARTICLE_ID: Int = 15
    """The particle ID of `EndermanTeleport`."""


@fieldwise_init
struct SnowballPoof(ImplicitlyCopyable, Particle):
    """A particle shown when a snowball collides with something (Go
    `particle.SnowballPoof`)."""

    comptime PARTICLE_ID: Int = 16
    """The particle ID of `SnowballPoof`."""


@fieldwise_init
struct EggSmash(ImplicitlyCopyable, Particle):
    """A particle shown when an egg smashes on something (Go
    `particle.EggSmash`)."""

    comptime PARTICLE_ID: Int = 17
    """The particle ID of `EggSmash`."""


struct Splash(ImplicitlyCopyable, Particle):
    """A particle that shows up when a splash potion is splashed (Go
    `particle.Splash`)."""

    comptime PARTICLE_ID: Int = 18
    """The particle ID of `Splash`."""

    var colour: RGBA
    """Colour is the colour that should be splashed."""

    def __init__(out self, *, colour: RGBA = RGBA()):
        """Creates the value; omitted fields take Go zero values.

        Args:
            colour: Colour is the colour that should be splashed.
        """
        self.colour = colour


struct Effect(ImplicitlyCopyable, Particle):
    """A particle that shows up around an entity when it has effects on (Go
    `particle.Effect`)."""

    comptime PARTICLE_ID: Int = 19
    """The particle ID of `Effect`."""

    var colour: RGBA
    """Colour is the colour of the particle."""

    def __init__(out self, *, colour: RGBA = RGBA()):
        """Creates the value; omitted fields take Go zero values.

        Args:
            colour: Colour is the colour of the particle.
        """
        self.colour = colour


@fieldwise_init
struct EntityFlame(ImplicitlyCopyable, Particle):
    """A particle shown when an entity is set on fire (Go
    `particle.EntityFlame`)."""

    comptime PARTICLE_ID: Int = 20
    """The particle ID of `EntityFlame`."""
