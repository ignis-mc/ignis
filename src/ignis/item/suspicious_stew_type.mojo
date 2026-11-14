"""`StewType`, ported from Dragonfly `server/item/suspicious_stew_type.go`."""

from ..entity.effect import SECOND, Effect, new
from ..entity.effect.blindness import Blindness
from ..entity.effect.fire_resistance import FireResistance
from ..entity.effect.jump_boost import JumpBoost
from ..entity.effect.nausea import Nausea
from ..entity.effect.night_vision import NightVision
from ..entity.effect.poison import Poison
from ..entity.effect.regeneration import Regeneration
from ..entity.effect.saturation import Saturation
from ..entity.effect.weakness import Weakness
from ..entity.effect.wither import Wither


struct StewType(Equatable, ImplicitlyCopyable):
    """The flower a suspicious stew was made with (Go `StewType`)."""

    var _v: UInt8

    comptime NIGHT_VISION_POPPY = StewType(0)
    """Go `NightVisionPoppyStew()`."""
    comptime JUMP_BOOST = StewType(1)
    """Go `JumpBoostStew()`."""
    comptime WEAKNESS = StewType(2)
    """Go `WeaknessStew()`."""
    comptime BLINDNESS_BLUET = StewType(3)
    """Go `BlindnessBluetStew()`."""
    comptime POISON = StewType(4)
    """Go `PoisonStew()`."""
    comptime SATURATION_DANDELION = StewType(5)
    """Go `SaturationDandelionStew()`."""
    comptime SATURATION_ORCHID = StewType(6)
    """Go `SaturationOrchidStew()`."""
    comptime FIRE_RESISTANCE = StewType(7)
    """Go `FireResistanceStew()`."""
    comptime REGENERATION = StewType(8)
    """Go `RegenerationStew()`."""
    comptime WITHER = StewType(9)
    """Go `WitherStew()`."""
    comptime NIGHT_VISION_TORCHFLOWER = StewType(10)
    """Go `NightVisionTorchflowerStew()`."""
    comptime BLINDNESS_EYEBLOSSOM = StewType(11)
    """Go `BlindnessEyeblossomStew()`."""
    comptime NAUSEA = StewType(12)
    """Go `NauseaStew()`."""

    def __init__(out self, v: Int):
        """Creates the stew type with index `v`, 0 to 12 (Go `StewType{v}`)."""
        self._v = UInt8(v)

    def __eq__(self, other: Self) -> Bool:
        """Compares two stew types."""
        return self._v == other._v

    def uint8(self) -> UInt8:
        """Returns the stew type as a byte, its item metadata (Go `Uint8`)."""
        return self._v

    def effects(self) -> List[Effect]:
        """Returns the effects eating the stew gives (Go `Effects`)."""
        var v = Int(self._v)
        if v == 0 or v == 10:
            return [new(NightVision(), 1, 5 * SECOND)]
        if v == 1:
            return [new(JumpBoost(), 1, 5 * SECOND)]
        if v == 2:
            return [new(Weakness(), 1, 7 * SECOND)]
        if v == 3 or v == 11:
            return [new(Blindness(), 1, 6 * SECOND)]
        if v == 4:
            return [new(Poison(), 1, 11 * SECOND)]
        if v == 5 or v == 6:
            return [new(Saturation(), 1, SECOND * 3 // 10)]
        if v == 7:
            return [new(FireResistance(), 1, 3 * SECOND)]
        if v == 8:
            return [new(Regeneration(), 1, 7 * SECOND)]
        if v == 9:
            return [new(Wither(), 1, 7 * SECOND)]
        return [new(Nausea(), 1, 7 * SECOND)]


def stew_types() -> List[StewType]:
    """Returns every stew type (Go `StewTypes`)."""
    var out = List[StewType](capacity=13)
    for i in range(13):
        out.append(StewType(i))
    return out^
