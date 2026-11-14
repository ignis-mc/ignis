"""Registration of the enchantments, ported from Dragonfly
`server/item/enchantment/register.go`.

Go registers each enchantment with its ID; here each type has its ID as
`ID`, and `VanillaEnchantments` lists the types for lookups by ID.
"""

from . import EnchantmentSet
from .aqua_affinity import AquaAffinity
from .blast_protection import BlastProtection
from .depth_strider import DepthStrider
from .efficiency import Efficiency
from .feather_falling import FeatherFalling
from .fire_aspect import FireAspect
from .fire_protection import FireProtection
from .flame import Flame
from .fortune import Fortune
from .infinity import Infinity
from .knockback import Knockback
from .mending import Mending
from .multishot import Multishot
from .piercing import Piercing
from .power import Power
from .projectile_protection import ProjectileProtection
from .protection import Protection
from .punch import Punch
from .quick_charge import QuickCharge
from .respiration import Respiration
from .sharpness import Sharpness
from .silk_touch import SilkTouch
from .soul_speed import SoulSpeed
from .swift_sneak import SwiftSneak
from .thorns import Thorns
from .unbreaking import Unbreaking
from .vanishing import CurseOfVanishing

comptime VanillaEnchantments = EnchantmentSet[
    AquaAffinity,
    BlastProtection,
    CurseOfVanishing,
    DepthStrider,
    Efficiency,
    FeatherFalling,
    FireAspect,
    FireProtection,
    Flame,
    Fortune,
    Infinity,
    Knockback,
    Mending,
    Multishot,
    Piercing,
    Power,
    ProjectileProtection,
    Protection,
    Punch,
    QuickCharge,
    Respiration,
    Sharpness,
    SilkTouch,
    SoulSpeed,
    SwiftSneak,
    Thorns,
    Unbreaking,
]
"""Every enchantment Dragonfly registers, sorted by name."""
