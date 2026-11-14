"""Registration of the vanilla entity types, ported from Dragonfly
`server/entity/register.go`."""

from ..world.entity import EntitySet
from .area_effect_cloud import AreaEffectCloud
from .arrow import Arrow
from .bottle_of_enchanting import BottleOfEnchanting
from .egg import Egg
from .ender_pearl import EnderPearl
from .experience_orb import ExperienceOrb
from .falling_block import FallingBlock
from .firework import Firework
from .item import ItemBehaviour
from .lightning import Lightning
from .lingering_potion import LingeringPotion
from .player_proxy import PlayerProxy
from .snowball import Snowball
from .splash_potion import SplashPotion
from .text import Text
from .tnt import TNT

comptime VanillaEntities = EntitySet[
    AreaEffectCloud,
    Arrow,
    BottleOfEnchanting,
    Egg,
    EnderPearl,
    ExperienceOrb,
    FallingBlock,
    Firework,
    ItemBehaviour,
    Lightning,
    LingeringPotion,
    Snowball,
    SplashPotion,
    TNT,
    Text,
    PlayerProxy,
]
"""Every entity type Ignis implements, in Go's order (the end crystal is
not ported), then the stand-in of players (`PlayerProxy`)."""
