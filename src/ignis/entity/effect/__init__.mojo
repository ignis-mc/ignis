"""Effects, ported from Dragonfly `server/entity/effect/effect.go`; the
effect types live in this package's other modules.

Go's `effect.Type` and `effect.LastingType` are interfaces whose values are
the effect type singletons (`effect.Speed`). Here each effect type is a
struct with its registered `ID`; an `Effect` stores the ID of its type
together with the type's colour and whether it lasts, which is all the
non-entity code needs. `Apply`, `Start` and `End` act on entities:
TODO(world-runtime) on each type.

Durations are in nanoseconds (Go `time.Duration`).
"""

from ...internal.color import RGBA

comptime SECOND: Int = 1_000_000_000
"""One second in nanoseconds (Go `time.Second`)."""


trait EffectType(Copyable, Defaultable, Deinitable):
    """A type of effect that may be added to an entity (Go `effect.Type`)."""

    comptime ID: Int
    """The ID the effect is registered with (Go `effect.ID`)."""

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's particles (Go `RGBA`).

        Returns:
            The colour.
        """
        ...


trait LastingType(EffectType):
    """An effect that lasts for a duration (Go `effect.LastingType`); the
    others are instant."""

    pass


struct Effect(Equatable, ImplicitlyCopyable):
    """An effect that may be added to an entity: a type with a level and,
    for lasting effects, a duration (Go `effect.Effect`)."""

    var _t: Int
    var _lasting: Bool
    var _colour: RGBA
    var _d: Int
    var _lvl: Int
    var _potency: Float64
    var _ambient: Bool
    var _particles_hidden: Bool
    var _infinite: Bool
    var _tick: Int

    def __init__[
        T: EffectType
    ](
        out self,
        t: T,
        lasting: Bool,
        lvl: Int,
        d: Int,
        potency: Float64,
        ambient: Bool,
        infinite: Bool,
    ):
        """Creates an effect; use `new_instant`, `new` and the other
        constructors.

        Parameters:
            T: The effect type.

        Args:
            t: The effect type.
            lasting: Whether `T` is a `LastingType`.
            lvl: The level.
            d: The duration in nanoseconds.
            potency: The potency of an instant effect.
            ambient: Whether the effect comes from an ambient source.
            infinite: Whether the effect lasts forever.
        """
        self._t = T.ID
        self._lasting = lasting
        self._colour = t.rgba()
        self._d = d
        self._lvl = lvl
        self._potency = potency
        self._ambient = ambient
        self._particles_hidden = False
        self._infinite = infinite
        self._tick = 0

    def __eq__(self, other: Self) -> Bool:
        """Compares two effects field by field (Go `==`).

        Args:
            other: The effect to compare with.

        Returns:
            True if both are equal.
        """
        return (
            self._t == other._t
            and self._d == other._d
            and self._lvl == other._lvl
            and self._potency == other._potency
            and self._ambient == other._ambient
            and self._particles_hidden == other._particles_hidden
            and self._infinite == other._infinite
            and self._tick == other._tick
        )

    def without_particles(self) -> Self:
        """Returns the effect with its particles hidden (Go
        `WithoutParticles`).

        Returns:
            The updated effect.
        """
        var e = self
        e._particles_hidden = True
        return e

    def particles_hidden(self) -> Bool:
        """Reports whether the effect's particles are hidden (Go
        `ParticlesHidden`).

        Returns:
            True if hidden.
        """
        return self._particles_hidden

    def level(self) -> Int:
        """Returns the level of the effect (Go `Level`).

        Returns:
            The level.
        """
        return self._lvl

    def duration(self) -> Int:
        """Returns the remaining duration (Go `Duration`).

        Returns:
            Nanoseconds; 0 for instant and infinite effects.
        """
        return self._d

    def ambient(self) -> Bool:
        """Reports whether the effect comes from an ambient source such as a
        beacon (Go `Ambient`).

        Returns:
            True if ambient.
        """
        return self._ambient

    def infinite(self) -> Bool:
        """Reports whether the effect lasts forever (Go `Infinite`).

        Returns:
            True if infinite.
        """
        return self._infinite

    def potency(self) -> Float64:
        """Returns the potency of an instant effect (Go `potency`, read by
        the instant effects' `Apply`).

        Returns:
            The potency; 1 by default.
        """
        return self._potency

    def type_id(self) -> Int:
        """Returns the ID of the effect's type (Go `Type`, which returns the
        type itself).

        Returns:
            The registered effect ID.
        """
        return self._t

    def lasting(self) -> Bool:
        """Reports whether the effect's type is a `LastingType` (Go
        `e.Type().(LastingType)`).

        Returns:
            True for lasting effects.
        """
        return self._lasting

    def rgba(self) -> RGBA:
        """Returns the colour of the effect's type (Go `e.Type().RGBA()`).

        Returns:
            The colour.
        """
        return self._colour

    def tick_duration(self) -> Self:
        """Returns the effect one tick later: lasting effects lose 1/20 of a
        second unless infinite, and count the tick (Go `TickDuration`).

        Returns:
            The updated effect.
        """
        var e = self
        if e._lasting:
            if not e._infinite:
                e._d -= SECOND // 20
            e._tick += 1
        return e

    def tick(self) -> Int:
        """Returns how many ticks the effect has been active (Go `Tick`).

        Returns:
            The tick count.
        """
        return self._tick


def new_instant[T: EffectType](t: T, lvl: Int) -> Effect:
    """Creates an instant effect with potency 1 (Go `NewInstant`).

    Parameters:
        T: The effect type.

    Args:
        t: The effect type.
        lvl: The level.

    Returns:
        The effect.
    """
    return new_instant_with_potency(t, lvl, 1)


def new_instant_with_potency[
    T: EffectType
](t: T, lvl: Int, potency: Float64) -> Effect:
    """Creates an instant effect with a potency (Go
    `NewInstantWithPotency`).

    Parameters:
        T: The effect type.

    Args:
        t: The effect type.
        lvl: The level.
        potency: The potency, scaling the effect.

    Returns:
        The effect.
    """
    return Effect(t, False, lvl, 0, potency, False, False)


def new[T: LastingType](t: T, lvl: Int, d: Int) -> Effect:
    """Creates a lasting effect (Go `New`).

    Parameters:
        T: The effect type.

    Args:
        t: The effect type.
        lvl: The level.
        d: The duration in nanoseconds.

    Returns:
        The effect.
    """
    return Effect(t, True, lvl, d, 0, False, False)


def new_ambient[T: LastingType](t: T, lvl: Int, d: Int) -> Effect:
    """Creates a lasting effect from an ambient source such as a beacon
    (Go `NewAmbient`).

    Parameters:
        T: The effect type.

    Args:
        t: The effect type.
        lvl: The level.
        d: The duration in nanoseconds.

    Returns:
        The effect.
    """
    return Effect(t, True, lvl, d, 0, True, False)


def new_infinite[T: LastingType](t: T, lvl: Int) -> Effect:
    """Creates a lasting effect without an end (Go `NewInfinite`).

    Parameters:
        T: The effect type.

    Args:
        t: The effect type.
        lvl: The level.

    Returns:
        The effect.
    """
    return Effect(t, True, lvl, 0, 0, False, True)


def resulting_colour(effects: List[Effect]) -> Tuple[RGBA, Bool]:
    """Returns the colour of the particles of a set of effects: the average
    of the visible effects' colours (Go `ResultingColour`).

    Args:
        effects: The effects.

    Returns:
        The colour, or the default potion colour if no effect is visible,
        and whether all visible effects are ambient.
    """
    var r = 0
    var g = 0
    var b = 0
    var a = 0
    var n = 0
    var ambient = True
    for e in effects:
        if e._particles_hidden:
            continue
        var c = e._colour
        r += Int(c.r)
        g += Int(c.g)
        b += Int(c.b)
        a += Int(c.a)
        n += 1
        if not e._ambient:
            ambient = False
    if n == 0:
        return (RGBA(0x38, 0x5D, 0xC6, 0xFF), False)
    return (
        RGBA(UInt8(r // n), UInt8(g // n), UInt8(b // n), UInt8(a // n)),
        ambient,
    )


struct EffectSet[*Ts: EffectType]:
    """A compile-time list of effect types (no Go counterpart: it replaces
    Go's `effects` map).

    Parameters:
        Ts: The effect types, each with a distinct `ID`.
    """

    @staticmethod
    def contains(id: Int) -> Bool:
        """Reports whether an effect with the ID is in the set (Go
        `ByID`'s `ok`).

        Args:
            id: The effect ID.

        Returns:
            True if one of `Ts` has that ID.
        """
        comptime for i in range(len(Self.Ts)):
            if id == Self.Ts[i].ID:
                return True
        return False

    @staticmethod
    def ids() -> List[Int]:
        """Returns the IDs of the effects in the set.

        Returns:
            The IDs, in the order of `Ts`.
        """
        var out = List[Int]()
        comptime for i in range(len(Self.Ts)):
            out.append(Self.Ts[i].ID)
        return out^

    @staticmethod
    def rgba(id: Int) -> Optional[RGBA]:
        """Returns the colour of the effect with an ID.

        Args:
            id: The effect ID.

        Returns:
            The colour, or None for an unknown ID.
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            if id == T.ID:
                return T().rgba()
        return None

    @staticmethod
    def lasting(id: Int) -> Optional[Bool]:
        """Reports whether the effect with an ID is lasting.

        Args:
            id: The effect ID.

        Returns:
            True for lasting effects, or None for an unknown ID.
        """
        comptime for i in range(len(Self.Ts)):
            comptime T = Self.Ts[i]
            if id == T.ID:
                return conforms_to(T, LastingType)
        return None
