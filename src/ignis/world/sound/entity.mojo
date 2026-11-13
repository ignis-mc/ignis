"""The entity sounds, ported from Dragonfly `server/world/sound/entity.go`.
"""

from . import Sound


struct Attack(ImplicitlyCopyable, Sound):
    """A sound played when an entity, most notably a player, attacks another
    entity (Go `sound.Attack`)."""

    comptime SOUND_ID: Int = 54
    """The sound ID of `Attack`."""

    var damage: Bool
    """Damage specifies if the attack actually dealt damage to the other
    entity. If set to false, the sound will be different from when
    set to true."""

    def __init__(out self, *, damage: Bool = False):
        """Creates the value; omitted fields take Go zero values.

        Args:
            damage: Damage specifies if the attack actually dealt damage to...
        """
        self.damage = damage


@fieldwise_init
struct Drowning(ImplicitlyCopyable, Sound):
    """A sound played when an entity is drowning in water (Go
    `sound.Drowning`)."""

    comptime SOUND_ID: Int = 55
    """The sound ID of `Drowning`."""


@fieldwise_init
struct Burning(ImplicitlyCopyable, Sound):
    """A sound played when an entity is on fire (Go `sound.Burning`)."""

    comptime SOUND_ID: Int = 56
    """The sound ID of `Burning`."""


struct Fall(ImplicitlyCopyable, Sound):
    """A sound played when an entity falls and hits ground (Go `sound.Fall`)."""

    comptime SOUND_ID: Int = 57
    """The sound ID of `Fall`."""

    var distance: Float64
    """Distance is the distance the entity has fallen."""

    def __init__(out self, *, distance: Float64 = 0):
        """Creates the value; omitted fields take Go zero values.

        Args:
            distance: Distance is the distance the entity has fallen.
        """
        self.distance = distance


@fieldwise_init
struct Burp(ImplicitlyCopyable, Sound):
    """A sound played when a player finishes eating an item (Go `sound.Burp`).
    """

    comptime SOUND_ID: Int = 58
    """The sound ID of `Burp`."""


@fieldwise_init
struct Pop(ImplicitlyCopyable, Sound):
    """A sound played when a chicken lays an egg (Go `sound.Pop`)."""

    comptime SOUND_ID: Int = 59
    """The sound ID of `Pop`."""


@fieldwise_init
struct Explosion(ImplicitlyCopyable, Sound):
    """A sound played when an explosion happens, such as from a creeper or TNT
    (Go `sound.Explosion`)."""

    comptime SOUND_ID: Int = 60
    """The sound ID of `Explosion`."""


@fieldwise_init
struct Thunder(ImplicitlyCopyable, Sound):
    """A sound played when lightning strikes the ground (Go `sound.Thunder`)."""

    comptime SOUND_ID: Int = 61
    """The sound ID of `Thunder`."""


@fieldwise_init
struct LevelUp(ImplicitlyCopyable, Sound):
    """A sound played for a player whenever they level up (Go `sound.LevelUp`).
    """

    comptime SOUND_ID: Int = 62
    """The sound ID of `LevelUp`."""


@fieldwise_init
struct Experience(ImplicitlyCopyable, Sound):
    """A sound played whenever a player picks up an XP orb (Go
    `sound.Experience`)."""

    comptime SOUND_ID: Int = 63
    """The sound ID of `Experience`."""


@fieldwise_init
struct GhastWarning(ImplicitlyCopyable, Sound):
    """A sound played when a ghast is ready to attack (Go
    `sound.GhastWarning`)."""

    comptime SOUND_ID: Int = 64
    """The sound ID of `GhastWarning`."""


@fieldwise_init
struct GhastShoot(ImplicitlyCopyable, Sound):
    """A sound played when a ghast shoots a fire charge (Go
    `sound.GhastShoot`)."""

    comptime SOUND_ID: Int = 65
    """The sound ID of `GhastShoot`."""


@fieldwise_init
struct FireworkLaunch(ImplicitlyCopyable, Sound):
    """A sound played when a firework is launched (Go `sound.FireworkLaunch`).
    """

    comptime SOUND_ID: Int = 66
    """The sound ID of `FireworkLaunch`."""


@fieldwise_init
struct FireworkHugeBlast(ImplicitlyCopyable, Sound):
    """A sound played when a huge sphere firework explodes (Go
    `sound.FireworkHugeBlast`)."""

    comptime SOUND_ID: Int = 67
    """The sound ID of `FireworkHugeBlast`."""


@fieldwise_init
struct FireworkBlast(ImplicitlyCopyable, Sound):
    """A sound played when a small sphere firework explodes (Go
    `sound.FireworkBlast`)."""

    comptime SOUND_ID: Int = 68
    """The sound ID of `FireworkBlast`."""


@fieldwise_init
struct FireworkTwinkle(ImplicitlyCopyable, Sound):
    """A sound played when a firework explodes and should twinkle (Go
    `sound.FireworkTwinkle`)."""

    comptime SOUND_ID: Int = 69
    """The sound ID of `FireworkTwinkle`."""
