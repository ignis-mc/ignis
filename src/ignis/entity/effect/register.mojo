"""Registration of the effects, ported from Dragonfly
`server/entity/effect/register.go`.

Go registers each effect with its ID; here each type has its ID as `ID`,
and `VanillaEffects` lists the types for lookups by ID.
"""

from . import EffectSet
from .absorption import Absorption
from .blindness import Blindness
from .conduit_power import ConduitPower
from .darkness import Darkness
from .fatal_poison import FatalPoison
from .fire_resistance import FireResistance
from .haste import Haste
from .health_boost import HealthBoost
from .hunger import Hunger
from .instant_damage import InstantDamage
from .instant_health import InstantHealth
from .invisibility import Invisibility
from .jump_boost import JumpBoost
from .levitation import Levitation
from .mining_fatigue import MiningFatigue
from .nausea import Nausea
from .night_vision import NightVision
from .poison import Poison
from .regeneration import Regeneration
from .resistance import Resistance
from .saturation import Saturation
from .slow_falling import SlowFalling
from .slowness import Slowness
from .speed import Speed
from .strength import Strength
from .water_breathing import WaterBreathing
from .weakness import Weakness
from .wither import Wither

comptime VanillaEffects = EffectSet[
    Absorption,
    Blindness,
    ConduitPower,
    Darkness,
    FatalPoison,
    FireResistance,
    Haste,
    HealthBoost,
    Hunger,
    InstantDamage,
    InstantHealth,
    Invisibility,
    JumpBoost,
    Levitation,
    MiningFatigue,
    Nausea,
    NightVision,
    Poison,
    Regeneration,
    Resistance,
    Saturation,
    SlowFalling,
    Slowness,
    Speed,
    Strength,
    WaterBreathing,
    Weakness,
    Wither,
]
"""Every effect Dragonfly registers, sorted by name."""
