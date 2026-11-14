"""Registration of the vanilla biomes, ported from Dragonfly
`server/world/biome/register.go`.
"""

from . import BiomeRegistry, BiomeSet
from .badlands import Badlands
from .badlands_plateau import BadlandsPlateau
from .bamboo_jungle import BambooJungle
from .bamboo_jungle_hills import BambooJungleHills
from .basalt_deltas import BasaltDeltas
from .beach import Beach
from .birch_forest import BirchForest
from .birch_forest_hills import BirchForestHills
from .cherry_grove import CherryGrove
from .cold_ocean import ColdOcean
from .crimson_forest import CrimsonForest
from .dappled_forest import DappledForest
from .dark_forest import DarkForest
from .dark_forest_hills import DarkForestHills
from .deep_cold_ocean import DeepColdOcean
from .deep_dark import DeepDark
from .deep_frozen_ocean import DeepFrozenOcean
from .deep_lukewarm_ocean import DeepLukewarmOcean
from .deep_ocean import DeepOcean
from .deep_warm_ocean import DeepWarmOcean
from .desert import Desert
from .desert_hills import DesertHills
from .desert_lakes import DesertLakes
from .dripstone_caves import DripstoneCaves
from .end import End
from .eroded_badlands import ErodedBadlands
from .flower_forest import FlowerForest
from .forest import Forest
from .frozen_ocean import FrozenOcean
from .frozen_peaks import FrozenPeaks
from .frozen_river import FrozenRiver
from .giant_spruce_taiga_hills import GiantSpruceTaigaHills
from .giant_tree_taiga_hills import GiantTreeTaigaHills
from .gravelly_mountains_plus import GravellyMountainsPlus
from .grove import Grove
from .ice_spikes import IceSpikes
from .jagged_peaks import JaggedPeaks
from .jungle import Jungle
from .jungle_edge import JungleEdge
from .jungle_hills import JungleHills
from .legacy_frozen_ocean import LegacyFrozenOcean
from .lukewarm_ocean import LukewarmOcean
from .lush_caves import LushCaves
from .mangrove_swamp import MangroveSwamp
from .meadow import Meadow
from .modified_badlands_plateau import ModifiedBadlandsPlateau
from .modified_jungle import ModifiedJungle
from .modified_jungle_edge import ModifiedJungleEdge
from .modified_wooded_badlands_plateau import ModifiedWoodedBadlandsPlateau
from .mountain_edge import MountainEdge
from .mushroom_field_shore import MushroomFieldShore
from .mushroom_fields import MushroomFields
from .nether_wastes import NetherWastes
from .ocean import Ocean
from .old_growth_birch_forest import OldGrowthBirchForest
from .old_growth_pine_taiga import OldGrowthPineTaiga
from .old_growth_spruce_taiga import OldGrowthSpruceTaiga
from .pale_garden import PaleGarden
from .plains import Plains
from .river import River
from .savanna import Savanna
from .savanna_plateau import SavannaPlateau
from .shattered_savanna_plateau import ShatteredSavannaPlateau
from .snowy_beach import SnowyBeach
from .snowy_mountains import SnowyMountains
from .snowy_plains import SnowyPlains
from .snowy_slopes import SnowySlopes
from .snowy_taiga import SnowyTaiga
from .snowy_taiga_hills import SnowyTaigaHills
from .snowy_taiga_mountains import SnowyTaigaMountains
from .soul_sand_valley import SoulSandValley
from .stony_peaks import StonyPeaks
from .stony_shore import StonyShore
from .sulfur_caves import SulfurCaves
from .sunflower_plains import SunflowerPlains
from .swamp import Swamp
from .swamp_hills import SwampHills
from .taiga import Taiga
from .taiga_hills import TaigaHills
from .taiga_mountains import TaigaMountains
from .tall_birch_hills import TallBirchHills
from .warm_ocean import WarmOcean
from .warped_forest import WarpedForest
from .windswept_forest import WindsweptForest
from .windswept_gravelly_hills import WindsweptGravellyHills
from .windswept_hills import WindsweptHills
from .windswept_savanna import WindsweptSavanna
from .wooded_badlands_plateau import WoodedBadlandsPlateau
from .wooded_hills import WoodedHills

comptime VanillaBiomes = BiomeSet[
    Badlands,
    BadlandsPlateau,
    BambooJungle,
    BambooJungleHills,
    BasaltDeltas,
    Beach,
    BirchForest,
    BirchForestHills,
    CherryGrove,
    ColdOcean,
    CrimsonForest,
    DappledForest,
    DarkForest,
    DarkForestHills,
    DeepColdOcean,
    DeepDark,
    DeepFrozenOcean,
    DeepLukewarmOcean,
    DeepOcean,
    DeepWarmOcean,
    Desert,
    DesertHills,
    DesertLakes,
    DripstoneCaves,
    End,
    ErodedBadlands,
    FlowerForest,
    Forest,
    FrozenOcean,
    FrozenPeaks,
    FrozenRiver,
    GiantSpruceTaigaHills,
    GiantTreeTaigaHills,
    GravellyMountainsPlus,
    Grove,
    IceSpikes,
    JaggedPeaks,
    Jungle,
    JungleEdge,
    JungleHills,
    LegacyFrozenOcean,
    LukewarmOcean,
    LushCaves,
    MangroveSwamp,
    Meadow,
    ModifiedBadlandsPlateau,
    ModifiedJungle,
    ModifiedJungleEdge,
    ModifiedWoodedBadlandsPlateau,
    MountainEdge,
    MushroomFieldShore,
    MushroomFields,
    NetherWastes,
    Ocean,
    OldGrowthBirchForest,
    OldGrowthPineTaiga,
    OldGrowthSpruceTaiga,
    PaleGarden,
    Plains,
    River,
    Savanna,
    SavannaPlateau,
    ShatteredSavannaPlateau,
    SnowyBeach,
    SnowyMountains,
    SnowyPlains,
    SnowySlopes,
    SnowyTaiga,
    SnowyTaigaHills,
    SnowyTaigaMountains,
    SoulSandValley,
    StonyPeaks,
    StonyShore,
    SulfurCaves,
    SunflowerPlains,
    Swamp,
    SwampHills,
    Taiga,
    TaigaHills,
    TaigaMountains,
    TallBirchHills,
    WarmOcean,
    WarpedForest,
    WindsweptForest,
    WindsweptGravellyHills,
    WindsweptHills,
    WindsweptSavanna,
    WoodedBadlandsPlateau,
    WoodedHills,
]
"""Every biome Dragonfly registers, sorted by name."""


def vanilla_biome_registry() raises -> BiomeRegistry:
    """Builds the registry of the vanilla biomes, finalised (Go's
    `biome/register.go` `init` and `finaliseBiomeRegistry`)."""
    var r = BiomeRegistry()
    VanillaBiomes.register_all(r)
    r.finalise()
    return r^
