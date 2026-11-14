"""Registration of the vanilla items, ported from Dragonfly
`server/item/register.go` and the `world.RegisterItem` calls of
`server/block/register.go`.

Each type lists its values in `all_items`; `VanillaItems` lists the item
types and `VanillaBlockItems` the block types that are items.
`vanilla_item_registry` builds the registry a server uses.
"""

from ..block.air import Air
from ..block.bedrock import Bedrock
from ..block.dirt import Dirt
from ..block.glass import Glass
from ..block.glazed_terracotta import GlazedTerracotta
from ..block.grass import Grass
from ..block.magma import Magma
from ..block.melon import Melon
from ..block.melon_seeds import MelonSeeds
from ..block.moss_carpet import MossCarpet
from ..block.mud import Mud
from ..block.mud_bricks import MudBricks
from ..block.muddy_mangrove_roots import MuddyMangroveRoots
from ..block.mycelium import Mycelium
from ..block.nether_brick_fence import NetherBrickFence
from ..block.nether_bricks import NetherBricks
from ..block.nether_gold_ore import NetherGoldOre
from ..block.nether_sprouts import NetherSprouts
from ..block.nether_wart import NetherWart
from ..block.nether_wart_block import NetherWartBlock
from ..block.netherite import Netherite
from ..block.netherrack import Netherrack
from ..block.note import Note
from ..block.obsidian import Obsidian
from ..block.packed_ice import PackedIce
from ..block.packed_mud import PackedMud
from ..block.pink_petals import PinkPetals
from ..block.planks import Planks
from ..block.podzol import Podzol
from ..block.polished_blackstone_brick import PolishedBlackstoneBrick
from ..block.polished_cinnabar import PolishedCinnabar
from ..block.polished_sulfur import PolishedSulfur
from ..block.polished_tuff import PolishedTuff
from ..block.potato import Potato
from ..block.prismarine import Prismarine
from ..block.pumpkin import Pumpkin
from ..block.pumpkin_seeds import PumpkinSeeds
from ..block.purpur import Purpur, PurpurPillar
from ..block.quartz import Quartz, QuartzPillar
from ..block.quartz_bricks import QuartzBricks
from ..block.quartz_ore import NetherQuartzOre
from ..block.raw_copper import RawCopper as RawCopperBlock
from ..block.raw_gold import RawGold as RawGoldBlock
from ..block.raw_iron import RawIron as RawIronBlock
from ..block.red_shrub import RedShrub
from ..block.redstone_block import RedstoneBlock
from ..block.redstone_ore import RedstoneOre
from ..block.redstone_torch import RedstoneTorch
from ..block.redstone_wire import RedstoneWire
from ..block.reinforced_deepslate import ReinforcedDeepslate
from ..block.resin import Resin
from ..block.resin_bricks import ResinBricks
from ..block.sand import Sand
from ..block.sandstone import Sandstone
from ..block.sapling import Sapling
from ..block.sea_lantern import SeaLantern
from ..block.sea_pickle import SeaPickle
from ..block.shelf_mushroom import ShelfMushroom
from ..block.short_grass import ShortGrass
from ..block.shroomlight import Shroomlight
from ..block.shulker_box import ShulkerBox
from ..block.sign import Sign
from ..block.skull import Skull
from ..block.slab import Slab
from ..block.slime import Slime
from ..block.smithing_table import SmithingTable
from ..block.smoker import Smoker
from ..block.smooth_basalt import SmoothBasalt
from ..block.snow import Snow
from ..block.soul_sand import SoulSand
from ..block.soul_soil import SoulSoil
from ..block.sponge import Sponge
from ..block.spore_blossom import SporeBlossom
from ..block.stained_glass import StainedGlass
from ..block.stained_glass_pane import StainedGlassPane
from ..block.stained_terracotta import StainedTerracotta
from ..block.stairs import Stairs
from ..block.stone import Stone
from ..block.stone_bricks import StoneBricks
from ..block.stonecutter import Stonecutter
from ..block.straw_bed import StrawBed
from ..block.string import StringBlock
from ..block.sugar_cane import SugarCane
from ..block.sulfur import Sulfur
from ..block.sulfur_bricks import SulfurBricks
from ..block.tinted_glass import TintedGlass
from ..block.tnt import TNT
from ..block.torch import Torch
from ..block.tuff import Tuff
from ..block.tuff_bricks import TuffBricks
from ..block.vine import Vines
from ..block.wall import Wall
from ..block.wheat_seeds import WheatSeeds
from ..block.wood import Wood
from ..block.wood_door import WoodDoor
from ..block.wood_fence import WoodFence
from ..block.wood_fence_gate import WoodFenceGate
from ..block.wood_trapdoor import WoodTrapdoor
from ..block.wool import Wool
from ..world.item import ItemRegistry
from .amethyst_shard import AmethystShard
from .apple import Apple
from .baked_potato import BakedPotato
from .beef import Beef
from .beetroot import Beetroot
from .beetroot_soup import BeetrootSoup
from .blaze_powder import BlazePowder
from .blaze_rod import BlazeRod
from .bone import Bone
from .bone_meal import BoneMeal
from .book import Book
from .book_and_quill import BookAndQuill
from .bottle_of_enchanting import BottleOfEnchanting
from .bow import Bow
from .bowl import Bowl
from .bread import Bread
from .brick import Brick
from .carrot_on_a_stick import CarrotOnAStick
from .charcoal import Charcoal
from .clay_ball import ClayBall
from .clock import Clock
from .coal import Coal
from .compass import Compass
from .cookie import Cookie
from .copper_ingot import CopperIngot
from .copper_nugget import CopperNugget
from .crossbow import Crossbow
from .diamond import Diamond
from .disc_fragment import DiscFragment
from .dragon_breath import DragonBreath
from .dried_kelp import DriedKelp
from .dye import Dye
from .echo_shard import EchoShard
from .egg import Egg
from .elytra import Elytra
from .emerald import Emerald
from .enchanted_apple import EnchantedApple
from .enchanted_book import EnchantedBook
from .end_crystal import EndCrystal
from .ender_eye import EnderEye
from .ender_pearl import EnderPearl
from .feather import Feather
from .fermented_spider_eye import FermentedSpiderEye
from .fire_charge import FireCharge
from .firework import Firework
from .flint import Flint
from .flint_and_steel import FlintAndSteel
from .ghast_tear import GhastTear
from .glass_bottle import GlassBottle
from .glistering_melon_slice import GlisteringMelonSlice
from .glowstone_dust import GlowstoneDust
from .gold_ingot import GoldIngot
from .gold_nugget import GoldNugget
from .golden_apple import GoldenApple
from .golden_carrot import GoldenCarrot
from .gunpowder import Gunpowder
from .heart_of_the_sea import HeartOfTheSea
from .honey_bottle import HoneyBottle
from .honeycomb import Honeycomb
from .iron_ingot import IronIngot
from .iron_nugget import IronNugget
from .item_set import ItemSet
from .lapis_lazuli import LapisLazuli
from .leather import Leather
from .magma_cream import MagmaCream
from .melon_slice import MelonSlice
from .mushroom_stew import MushroomStew
from .nautilus_shell import NautilusShell
from .nether_brick import NetherBrick
from .nether_quartz import NetherQuartz
from .nether_star import NetherStar
from .netherite_ingot import NetheriteIngot
from .netherite_scrap import NetheriteScrap
from .paper import Paper
from .phantom_membrane import PhantomMembrane
from .poisonous_potato import PoisonousPotato
from .popped_chorus_fruit import PoppedChorusFruit
from .prismarine_crystal import PrismarineCrystals
from .prismarine_shard import PrismarineShard
from .pufferfish import Pufferfish
from .pumpkin_pie import PumpkinPie
from .rabbit_foot import RabbitFoot
from .rabbit_hide import RabbitHide
from .rabbit_stew import RabbitStew
from .raw_copper import RawCopper
from .raw_gold import RawGold
from .raw_iron import RawIron
from .recovery_compass import RecoveryCompass
from .resin_brick import ResinBrick
from .rotten_flesh import RottenFlesh
from .scute import Scute
from .shears import Shears
from .shulker_shell import ShulkerShell
from .slimeball import Slimeball
from .snowball import Snowball
from .spider_eye import SpiderEye
from .spyglass import Spyglass
from .stick import Stick
from .sugar import Sugar
from .totem import Totem
from .tropical_fish import TropicalFish
from .turtle_shell import TurtleShell
from .warped_fungus_on_a_stick import WarpedFungusOnAStick
from .wheat import Wheat
from .written_book import WrittenBook

comptime VanillaItems = ItemSet[
    AmethystShard,
    Apple,
    BakedPotato,
    Beef,
    Beetroot,
    BeetrootSoup,
    BlazePowder,
    BlazeRod,
    Bone,
    BoneMeal,
    Book,
    BookAndQuill,
    BottleOfEnchanting,
    Bow,
    Bowl,
    Bread,
    Brick,
    CarrotOnAStick,
    Charcoal,
    ClayBall,
    Clock,
    Coal,
    Compass,
    Cookie,
    CopperIngot,
    CopperNugget,
    Crossbow,
    Diamond,
    DiscFragment,
    DragonBreath,
    DriedKelp,
    Dye,
    EchoShard,
    Egg,
    Elytra,
    Emerald,
    EnchantedApple,
    EnchantedBook,
    EndCrystal,
    EnderEye,
    EnderPearl,
    Feather,
    FermentedSpiderEye,
    FireCharge,
    Firework,
    Flint,
    FlintAndSteel,
    GhastTear,
    GlassBottle,
    GlisteringMelonSlice,
    GlowstoneDust,
    GoldIngot,
    GoldNugget,
    GoldenApple,
    GoldenCarrot,
    Gunpowder,
    HeartOfTheSea,
    HoneyBottle,
    Honeycomb,
    IronIngot,
    IronNugget,
    LapisLazuli,
    Leather,
    MagmaCream,
    MelonSlice,
    MushroomStew,
    NautilusShell,
    NetherBrick,
    NetherQuartz,
    NetherStar,
    NetheriteIngot,
    NetheriteScrap,
    Paper,
    PhantomMembrane,
    PoisonousPotato,
    PoppedChorusFruit,
    PrismarineCrystals,
    PrismarineShard,
    Pufferfish,
    PumpkinPie,
    RabbitFoot,
    RabbitHide,
    RabbitStew,
    RawCopper,
    RawGold,
    RawIron,
    RecoveryCompass,
    ResinBrick,
    RottenFlesh,
    Scute,
    Shears,
    ShulkerShell,
    Slimeball,
    Snowball,
    SpiderEye,
    Spyglass,
    Stick,
    Sugar,
    Totem,
    TropicalFish,
    TurtleShell,
    WarpedFungusOnAStick,
    Wheat,
    WrittenBook,
]
"""Every item type Ignis implements, sorted by name."""

comptime VanillaBlockItems = ItemSet[
    Air,
    Bedrock,
    Dirt,
    Glass,
    GlazedTerracotta,
    Grass,
    Magma,
    Melon,
    MelonSeeds,
    MossCarpet,
    Mud,
    MudBricks,
    MuddyMangroveRoots,
    Mycelium,
    NetherBrickFence,
    NetherBricks,
    NetherGoldOre,
    NetherQuartzOre,
    NetherSprouts,
    NetherWart,
    NetherWartBlock,
    Netherite,
    Netherrack,
    Note,
    Obsidian,
    PackedIce,
    PackedMud,
    PinkPetals,
    Planks,
    Podzol,
    PolishedBlackstoneBrick,
    PolishedCinnabar,
    PolishedSulfur,
    PolishedTuff,
    Potato,
    Prismarine,
    Pumpkin,
    PumpkinSeeds,
    Purpur,
    PurpurPillar,
    Quartz,
    QuartzBricks,
    QuartzPillar,
    RawCopperBlock,
    RawGoldBlock,
    RawIronBlock,
    RedShrub,
    RedstoneBlock,
    RedstoneOre,
    RedstoneTorch,
    RedstoneWire,
    ReinforcedDeepslate,
    Resin,
    ResinBricks,
    Sand,
    Sandstone,
    Sapling,
    SeaLantern,
    SeaPickle,
    ShelfMushroom,
    ShortGrass,
    Shroomlight,
    ShulkerBox,
    Sign,
    Skull,
    Slab,
    Slime,
    SmithingTable,
    Smoker,
    SmoothBasalt,
    Snow,
    SoulSand,
    SoulSoil,
    Sponge,
    SporeBlossom,
    StainedGlass,
    StainedGlassPane,
    StainedTerracotta,
    Stairs,
    Stone,
    StoneBricks,
    Stonecutter,
    StrawBed,
    StringBlock,
    SugarCane,
    Sulfur,
    SulfurBricks,
    TNT,
    TintedGlass,
    Torch,
    Tuff,
    TuffBricks,
    Vines,
    Wall,
    WheatSeeds,
    Wood,
    WoodDoor,
    WoodFence,
    WoodFenceGate,
    WoodTrapdoor,
    Wool,
]
"""Every block type registered as an item, sorted by name."""

comptime VANILLA_ITEMS_PATH = "resources/vanilla_items.nbt"
"""Where `vanilla_items.nbt` lives, relative to the repository root."""


def vanilla_item_registry(
    path: String = VANILLA_ITEMS_PATH,
) raises -> ItemRegistry:
    """Builds the vanilla item registry: the runtime IDs of
    `vanilla_items.nbt` with every item and block item registered.

    Args:
        path: The path of `vanilla_items.nbt`.

    Returns:
        The registry.

    Raises:
        If the file cannot be read or an item has no runtime ID.
    """
    var reg = ItemRegistry.load(path)
    VanillaBlockItems.register_all(reg)
    VanillaItems.register_all(reg)
    return reg^
