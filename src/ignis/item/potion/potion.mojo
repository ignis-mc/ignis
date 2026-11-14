"""`Potion`, ported from Dragonfly `server/item/potion/potion.go`."""

from ...entity.effect import SECOND, Effect, new, new_instant
from ...entity.effect.fire_resistance import FireResistance
from ...entity.effect.instant_damage import InstantDamage
from ...entity.effect.instant_health import InstantHealth
from ...entity.effect.invisibility import Invisibility
from ...entity.effect.jump_boost import JumpBoost
from ...entity.effect.night_vision import NightVision
from ...entity.effect.poison import Poison
from ...entity.effect.regeneration import Regeneration
from ...entity.effect.resistance import Resistance
from ...entity.effect.slow_falling import SlowFalling
from ...entity.effect.slowness import Slowness
from ...entity.effect.speed import Speed
from ...entity.effect.strength import Strength
from ...entity.effect.water_breathing import WaterBreathing
from ...entity.effect.weakness import Weakness
from ...entity.effect.wither import Wither

comptime _MILLISECOND = SECOND // 1000
comptime _MINUTE = 60 * SECOND


struct Potion(Equatable, ImplicitlyCopyable, Writable):
    """A potion type: the effects a potion gives (Go `potion.Potion`)."""

    var _v: UInt8

    comptime WATER = Potion(0)
    """Go `Water()`."""
    comptime MUNDANE = Potion(1)
    """Go `Mundane()`."""
    comptime LONG_MUNDANE = Potion(2)
    """Go `LongMundane()`."""
    comptime THICK = Potion(3)
    """Go `Thick()`."""
    comptime AWKWARD = Potion(4)
    """Go `Awkward()`."""
    comptime NIGHT_VISION = Potion(5)
    """Go `NightVision()`."""
    comptime LONG_NIGHT_VISION = Potion(6)
    """Go `LongNightVision()`."""
    comptime INVISIBILITY = Potion(7)
    """Go `Invisibility()`."""
    comptime LONG_INVISIBILITY = Potion(8)
    """Go `LongInvisibility()`."""
    comptime LEAPING = Potion(9)
    """Go `Leaping()`."""
    comptime LONG_LEAPING = Potion(10)
    """Go `LongLeaping()`."""
    comptime STRONG_LEAPING = Potion(11)
    """Go `StrongLeaping()`."""
    comptime FIRE_RESISTANCE = Potion(12)
    """Go `FireResistance()`."""
    comptime LONG_FIRE_RESISTANCE = Potion(13)
    """Go `LongFireResistance()`."""
    comptime SWIFTNESS = Potion(14)
    """Go `Swiftness()`."""
    comptime LONG_SWIFTNESS = Potion(15)
    """Go `LongSwiftness()`."""
    comptime STRONG_SWIFTNESS = Potion(16)
    """Go `StrongSwiftness()`."""
    comptime SLOWNESS = Potion(17)
    """Go `Slowness()`."""
    comptime LONG_SLOWNESS = Potion(18)
    """Go `LongSlowness()`."""
    comptime WATER_BREATHING = Potion(19)
    """Go `WaterBreathing()`."""
    comptime LONG_WATER_BREATHING = Potion(20)
    """Go `LongWaterBreathing()`."""
    comptime HEALING = Potion(21)
    """Go `Healing()`."""
    comptime STRONG_HEALING = Potion(22)
    """Go `StrongHealing()`."""
    comptime HARMING = Potion(23)
    """Go `Harming()`."""
    comptime STRONG_HARMING = Potion(24)
    """Go `StrongHarming()`."""
    comptime POISON = Potion(25)
    """Go `Poison()`."""
    comptime LONG_POISON = Potion(26)
    """Go `LongPoison()`."""
    comptime STRONG_POISON = Potion(27)
    """Go `StrongPoison()`."""
    comptime REGENERATION = Potion(28)
    """Go `Regeneration()`."""
    comptime LONG_REGENERATION = Potion(29)
    """Go `LongRegeneration()`."""
    comptime STRONG_REGENERATION = Potion(30)
    """Go `StrongRegeneration()`."""
    comptime STRENGTH = Potion(31)
    """Go `Strength()`."""
    comptime LONG_STRENGTH = Potion(32)
    """Go `LongStrength()`."""
    comptime STRONG_STRENGTH = Potion(33)
    """Go `StrongStrength()`."""
    comptime WEAKNESS = Potion(34)
    """Go `Weakness()`."""
    comptime LONG_WEAKNESS = Potion(35)
    """Go `LongWeakness()`."""
    comptime WITHER = Potion(36)
    """Go `Wither()`."""
    comptime TURTLE_MASTER = Potion(37)
    """Go `TurtleMaster()`."""
    comptime LONG_TURTLE_MASTER = Potion(38)
    """Go `LongTurtleMaster()`."""
    comptime STRONG_TURTLE_MASTER = Potion(39)
    """Go `StrongTurtleMaster()`."""
    comptime SLOW_FALLING = Potion(40)
    """Go `SlowFalling()`."""
    comptime LONG_SLOW_FALLING = Potion(41)
    """Go `LongSlowFalling()`."""
    comptime STRONG_SLOWNESS = Potion(42)
    """Go `StrongSlowness()`."""

    def __init__(out self, v: Int):
        """Creates the potion with ID `v` (Go `From`)."""
        self._v = UInt8(v)

    def __init__(out self):
        """Creates a water potion (Go `Potion{}`)."""
        self._v = 0

    def __eq__(self, other: Self) -> Bool:
        """Compares two potions."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the potion ID (Go `Uint8`)."""
        return self._v

    def effects(self) -> List[Effect]:
        """Returns the effects of the potion (Go `Effects`)."""
        if self == Self.NIGHT_VISION:
            return [new(NightVision(), 1, 3 * _MINUTE)]
        if self == Self.LONG_NIGHT_VISION:
            return [new(NightVision(), 1, 8 * _MINUTE)]
        if self == Self.INVISIBILITY:
            return [new(Invisibility(), 1, 3 * _MINUTE)]
        if self == Self.LONG_INVISIBILITY:
            return [new(Invisibility(), 1, 8 * _MINUTE)]
        if self == Self.LEAPING:
            return [new(JumpBoost(), 1, 3 * _MINUTE)]
        if self == Self.LONG_LEAPING:
            return [new(JumpBoost(), 1, 8 * _MINUTE)]
        if self == Self.STRONG_LEAPING:
            return [new(JumpBoost(), 2, 90 * SECOND)]
        if self == Self.FIRE_RESISTANCE:
            return [new(FireResistance(), 1, 3 * _MINUTE)]
        if self == Self.LONG_FIRE_RESISTANCE:
            return [new(FireResistance(), 1, 8 * _MINUTE)]
        if self == Self.SWIFTNESS:
            return [new(Speed(), 1, 3 * _MINUTE)]
        if self == Self.LONG_SWIFTNESS:
            return [new(Speed(), 1, 8 * _MINUTE)]
        if self == Self.STRONG_SWIFTNESS:
            return [new(Speed(), 2, 90 * SECOND)]
        if self == Self.SLOWNESS:
            return [new(Slowness(), 1, 90 * SECOND)]
        if self == Self.LONG_SLOWNESS:
            return [new(Slowness(), 1, 4 * _MINUTE)]
        if self == Self.WATER_BREATHING:
            return [new(WaterBreathing(), 1, 3 * _MINUTE)]
        if self == Self.LONG_WATER_BREATHING:
            return [new(WaterBreathing(), 1, 8 * _MINUTE)]
        if self == Self.HEALING:
            return [new_instant(InstantHealth(), 1)]
        if self == Self.STRONG_HEALING:
            return [new_instant(InstantHealth(), 2)]
        if self == Self.HARMING:
            return [new_instant(InstantDamage(), 1)]
        if self == Self.STRONG_HARMING:
            return [new_instant(InstantDamage(), 2)]
        if self == Self.POISON:
            return [new(Poison(), 1, 45 * SECOND)]
        if self == Self.LONG_POISON:
            return [new(Poison(), 1, 2 * _MINUTE)]
        if self == Self.STRONG_POISON:
            return [new(Poison(), 2, 22500 * _MILLISECOND)]
        if self == Self.REGENERATION:
            return [new(Regeneration(), 1, 45 * SECOND)]
        if self == Self.LONG_REGENERATION:
            return [new(Regeneration(), 1, 2 * _MINUTE)]
        if self == Self.STRONG_REGENERATION:
            return [new(Regeneration(), 2, 22500 * _MILLISECOND)]
        if self == Self.STRENGTH:
            return [new(Strength(), 1, 3 * _MINUTE)]
        if self == Self.LONG_STRENGTH:
            return [new(Strength(), 1, 8 * _MINUTE)]
        if self == Self.STRONG_STRENGTH:
            return [new(Strength(), 2, 90 * SECOND)]
        if self == Self.WEAKNESS:
            return [new(Weakness(), 1, 90 * SECOND)]
        if self == Self.LONG_WEAKNESS:
            return [new(Weakness(), 1, 4 * _MINUTE)]
        if self == Self.WITHER:
            return [new(Wither(), 1, 40 * SECOND)]
        if self == Self.TURTLE_MASTER:
            return [
                new(Resistance(), 3, 20 * SECOND),
                new(Slowness(), 4, 20 * SECOND),
            ]
        if self == Self.LONG_TURTLE_MASTER:
            return [
                new(Resistance(), 3, 40 * SECOND),
                new(Slowness(), 4, 40 * SECOND),
            ]
        if self == Self.STRONG_TURTLE_MASTER:
            return [
                new(Resistance(), 5, 20 * SECOND),
                new(Slowness(), 6, 20 * SECOND),
            ]
        if self == Self.SLOW_FALLING:
            return [new(SlowFalling(), 1, 90 * SECOND)]
        if self == Self.LONG_SLOW_FALLING:
            return [new(SlowFalling(), 1, 4 * _MINUTE)]
        if self == Self.STRONG_SLOWNESS:
            return [new(Slowness(), 4, 20 * SECOND)]
        return []

    def write_to(self, mut writer: Some[Writer]):
        """Writes the potion ID."""
        writer.write("Potion(", self._v, ")")


def from_id(id: Int32) -> Potion:
    """Returns the potion with an ID (Go `From`)."""
    return Potion(Int(id))


def all_potions() -> List[Potion]:
    """Returns every potion, in ID order (Go `All`)."""
    var out = List[Potion](capacity=43)
    for i in range(43):
        out.append(Potion(i))
    return out^
