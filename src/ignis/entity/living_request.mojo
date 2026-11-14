"""What world entities do to living entities (Go calls `Living.Hurt`,
`KnockBack`, `AddEffect`, `SetOnFire`, `Teleport`, `Explode` and
`CollectExperience` on them directly).

The only living entities in Ignis are players, and the server owns them,
not the world. Each player has a `PlayerProxy` entity in the world; code
that would call a method on a living entity records a `LivingRequest` on
the proxy instead, and the server applies the requests to the player after
the world tick, in the order they were made.
"""

from ..mgl64 import Vec3
from .damage import AnyDamageSource
from .effect import Effect

comptime REQUEST_HURT = 0
"""Go `Hurt(dmg, src)`."""
comptime REQUEST_KNOCK_BACK = 1
"""Go `KnockBack(pos, force, height)`."""
comptime REQUEST_EFFECT = 2
"""Go `AddEffect` for each of `effects`."""
comptime REQUEST_FIRE = 3
"""Go `SetOnFire(fire_ms)`, only if it burns shorter (`at_least`)."""
comptime REQUEST_TELEPORT = 4
"""Go's ender pearl: a teleport sound, `Teleport(pos)` and 5 fall
damage."""
comptime REQUEST_EXPLODE = 5
"""Go `Explode(src, impact)` with the explosion at `pos` of `size`."""
comptime REQUEST_PROJECTILE_HIT = 6
"""Go `ProjectileBehaviour.hitEntity`: `Hurt(dmg, src)`, and if it was
vulnerable, `KnockBack(pos, force, height)`, the `effects` and
`SetOnFire(fire_ms)` if `fire_ms` is set."""
comptime REQUEST_COLLECT_EXPERIENCE = 7
"""Go `CollectExperience(value)` from an orb that was removed."""
comptime REQUEST_LIGHTNING = 8
"""Go's lightning: `Hurt(dmg, src)`, then `SetOnFire(fire_ms)` if it burns
shorter."""


struct LivingRequest(Copyable):
    """A call on a living entity, recorded for the server to apply."""

    var kind: Int
    """One of the `REQUEST_*` kinds."""
    var dmg: Float64
    """The damage of a hurt."""
    var src: AnyDamageSource
    """The source of a hurt."""
    var pos: Vec3
    """The knock-back source, teleport target or explosion position."""
    var force: Float64
    """The knock-back force."""
    var height: Float64
    """The knock-back height."""
    var size: Float64
    """The explosion size."""
    var impact: Float64
    """The explosion impact, 0 to 1."""
    var effects: List[Effect]
    """The effects to add."""
    var fire_ms: Int
    """How long to set the entity on fire; 0 for not at all."""
    var at_least: Bool
    """Only set the fire if the entity burns shorter."""
    var value: Int
    """The experience collected."""

    def __init__(out self, kind: Int):
        """Creates a request of a kind with nothing set."""
        self.kind = kind
        self.dmg = 0
        self.src = AnyDamageSource(0)
        self.pos = Vec3()
        self.force = 0
        self.height = 0
        self.size = 0
        self.impact = 0
        self.effects = List[Effect]()
        self.fire_ms = 0
        self.at_least = False
        self.value = 0

    @staticmethod
    def hurt(dmg: Float64, src: AnyDamageSource) -> Self:
        """Go `Hurt`."""
        var r = Self(REQUEST_HURT)
        r.dmg = dmg
        r.src = src
        return r^

    @staticmethod
    def knock_back(pos: Vec3, force: Float64, height: Float64) -> Self:
        """Go `KnockBack`."""
        var r = Self(REQUEST_KNOCK_BACK)
        r.pos = pos
        r.force = force
        r.height = height
        return r^

    @staticmethod
    def effect(e: Effect) -> Self:
        """Go `AddEffect`."""
        var r = Self(REQUEST_EFFECT)
        r.effects.append(e)
        return r^

    @staticmethod
    def fire(ms: Int, at_least: Bool = False) -> Self:
        """Go `SetOnFire`."""
        var r = Self(REQUEST_FIRE)
        r.fire_ms = ms
        r.at_least = at_least
        return r^
