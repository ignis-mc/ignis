"""Registration of the vanilla items, ported from Dragonfly
`server/item/register.go` and the `world.RegisterItem` calls of
`server/block/register.go`.

Each type lists its values in `all_items`; `VanillaItems` lists the item
types and `VanillaBlockItems` the block types that are items.
`vanilla_item_registry` builds the registry a server uses.
"""

from ..block.air import Air
from ..block.amethyst import Amethyst
from ..block.ancient_debris import AncientDebris
from ..block.anvil import Anvil
from ..block.bamboo import Bamboo
from ..block.bamboo_block import BambooBlock
from ..block.bamboo_mosaic import BambooMosaic
from ..block.banner import Banner
from ..block.barrel import Barrel
from ..block.barrier import Barrier
from ..block.basalt import Basalt
from ..block.beacon import Beacon
from ..block.bed import Bed
from ..block.bedrock import Bedrock
from ..block.beetroot_seeds import BeetrootSeeds
from ..block.blackstone import Blackstone
from ..block.blast_furnace import BlastFurnace
from ..block.blue_ice import BlueIce
from ..block.bone import Bone as BoneBlock
from ..block.bookshelf import Bookshelf
from ..block.brewing_stand import BrewingStand
from ..block.bricks import Bricks
from ..block.cactus import Cactus
from ..block.cake import Cake
from ..block.calcite import Calcite
from ..block.campfire import Campfire
from ..block.candle import Candle
from ..block.carpet import Carpet
from ..block.carrot import Carrot
from ..block.chest import Chest
from ..block.cinnabar import Cinnabar
from ..block.cinnabar_bricks import CinnabarBricks
from ..block.clay import Clay
from ..block.coal import Coal as CoalBlock
from ..block.coal_ore import CoalOre
from ..block.cobblestone import Cobblestone
from ..block.cobweb import Cobweb
from ..block.cocoa_bean import CocoaBean
from ..block.composter import Composter
from ..block.concrete import Concrete
from ..block.concrete_powder import ConcretePowder
from ..block.copper import Copper
from ..block.copper_bars import CopperBars
from ..block.copper_chain import CopperChain
from ..block.copper_door import CopperDoor
from ..block.copper_golem_statue import CopperGolemStatue
from ..block.copper_grate import CopperGrate
from ..block.copper_lantern import CopperLantern
from ..block.copper_ore import CopperOre
from ..block.copper_torch import CopperTorch
from ..block.copper_trapdoor import CopperTrapdoor
from ..block.coral import Coral
from ..block.coral_block import CoralBlock
from ..block.crafting_table import CraftingTable
from ..block.deadbush import DeadBush
from ..block.decorated_pot import DecoratedPot
from ..block.deepslate import Deepslate
from ..block.deepslate_bricks import DeepslateBricks
from ..block.deepslate_tiles import DeepslateTiles
from ..block.diamond import Diamond as DiamondBlock
from ..block.diamond_ore import DiamondOre
from ..block.dirt import Dirt
from ..block.dirt_path import DirtPath
from ..block.double_flower import DoubleFlower
from ..block.double_tall_grass import DoubleTallGrass
from ..block.dragon_egg import DragonEgg
from ..block.dried_kelp import DriedKelp as DriedKelpBlock
from ..block.dripstone import Dripstone
from ..block.emerald import Emerald as EmeraldBlock
from ..block.emerald_ore import EmeraldOre
from ..block.enchanting_table import EnchantingTable
from ..block.end_bricks import EndBricks
from ..block.end_portal_frame import EndPortalFrame
from ..block.end_rod import EndRod
from ..block.end_stone import EndStone
from ..block.ender_chest import EnderChest
from ..block.farmland import Farmland
from ..block.fern import Fern
from ..block.fletching_table import FletchingTable
from ..block.flower import Flower
from ..block.froglight import Froglight
from ..block.furnace import Furnace
from ..block.glass_pane import GlassPane
from ..block.glowstone import Glowstone
from ..block.gold import Gold
from ..block.gold_ore import GoldOre
from ..block.grass import Grass
from ..block.gravel import Gravel
from ..block.grindstone import Grindstone
from ..block.hay_bale import HayBale
from ..block.honeycomb import Honeycomb as HoneycombBlock
from ..block.hopper import Hopper
from ..block.ice import Ice
from ..block.infested_cobblestone import InfestedCobblestone
from ..block.infested_deepslate import InfestedDeepslate
from ..block.infested_stone import InfestedStone
from ..block.infested_stone_bricks import InfestedStoneBricks
from ..block.invisible_bedrock import InvisibleBedrock
from ..block.iron import Iron
from ..block.iron_bars import IronBars
from ..block.iron_chain import IronChain
from ..block.iron_ore import IronOre
from ..block.item_frame import ItemFrame
from ..block.jukebox import Jukebox
from ..block.kelp import Kelp
from ..block.ladder import Ladder
from ..block.lantern import Lantern
from ..block.lapis import Lapis
from ..block.lapis_ore import LapisOre
from ..block.leaves import Leaves
from ..block.lectern import Lectern
from ..block.lever import Lever
from ..block.light import Light
from ..block.lily_pad import LilyPad
from ..block.lit_pumpkin import LitPumpkin
from ..block.log import Log
from ..block.loom import Loom
from ..block.quartz import ChiseledQuartz
from ..block.stone import Andesite, Diorite, Granite, Stone
from ..block.terracotta import Terracotta
from ..world.item import ItemRegistry
from .amethyst_shard import AmethystShard
from .apple import Apple
from .arrow import Arrow
from .axe import Axe
from .baked_potato import BakedPotato
from .banner_pattern import BannerPattern
from .beef import Beef
from .beetroot import Beetroot
from .beetroot_soup import BeetrootSoup
from .blaze_powder import BlazePowder
from .blaze_rod import BlazeRod
from .bone import Bone
from .bone_meal import BoneMeal
from .book import Book
from .book_and_quill import BookAndQuill
from .boots import Boots
from .bottle_of_enchanting import BottleOfEnchanting
from .bow import Bow
from .bowl import Bowl
from .bread import Bread
from .brick import Brick
from .bucket import Bucket
from .carrot_on_a_stick import CarrotOnAStick
from .charcoal import Charcoal
from .chestplate import Chestplate
from .chicken import Chicken
from .clay_ball import ClayBall
from .clock import Clock
from .coal import Coal
from .cod import Cod
from .compass import Compass
from .cookie import Cookie
from .copper_ingot import CopperIngot
from .copper_nugget import CopperNugget
from .crossbow import Crossbow
from .diamond import Diamond
from .disc_fragment import DiscFragment
from .dragon_breath import DragonBreath
from .dried_kelp import DriedKelp
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
from .firework_star import FireworkStar
from .flint import Flint
from .flint_and_steel import FlintAndSteel
from .ghast_tear import GhastTear
from .glass_bottle import GlassBottle
from .glistering_melon_slice import GlisteringMelonSlice
from .glowstone_dust import GlowstoneDust
from .goat_horn import GoatHorn
from .gold_ingot import GoldIngot
from .gold_nugget import GoldNugget
from .golden_apple import GoldenApple
from .golden_carrot import GoldenCarrot
from .gunpowder import Gunpowder
from .heart_of_the_sea import HeartOfTheSea
from .helmet import Helmet
from .hoe import Hoe
from .honey_bottle import HoneyBottle
from .honeycomb import Honeycomb
from .ink_sac import InkSac
from .iron_ingot import IronIngot
from .iron_nugget import IronNugget
from .item_set import ItemSet
from .lapis_lazuli import LapisLazuli
from .leather import Leather
from .leggings import Leggings
from .lingering_potion import LingeringPotion
from .magma_cream import MagmaCream
from .melon_slice import MelonSlice
from .mushroom_stew import MushroomStew
from .music_disc import MusicDisc
from .mutton import Mutton
from .nautilus_shell import NautilusShell
from .nether_brick import NetherBrick
from .nether_quartz import NetherQuartz
from .nether_star import NetherStar
from .netherite_ingot import NetheriteIngot
from .netherite_scrap import NetheriteScrap
from .paper import Paper
from .phantom_membrane import PhantomMembrane
from .pickaxe import Pickaxe
from .poisonous_potato import PoisonousPotato
from .popped_chorus_fruit import PoppedChorusFruit
from .porkchop import Porkchop
from .potion import Potion
from .pottery_sherd import PotterySherd
from .prismarine_crystal import PrismarineCrystals
from .prismarine_shard import PrismarineShard
from .pufferfish import Pufferfish
from .pumpkin_pie import PumpkinPie
from .rabbit import Rabbit
from .rabbit_foot import RabbitFoot
from .rabbit_hide import RabbitHide
from .rabbit_stew import RabbitStew
from .raw_copper import RawCopper
from .raw_gold import RawGold
from .raw_iron import RawIron
from .recovery_compass import RecoveryCompass
from .resin_brick import ResinBrick
from .rotten_flesh import RottenFlesh
from .salmon import Salmon
from .scute import Scute
from .shears import Shears
from .shovel import Shovel
from .shulker_shell import ShulkerShell
from .slimeball import Slimeball
from .smithing_template import SmithingTemplate
from .snowball import Snowball
from .spider_eye import SpiderEye
from .splash_potion import SplashPotion
from .spyglass import Spyglass
from .stick import Stick
from .sugar import Sugar
from .suspicious_stew import SuspiciousStew
from .sword import Sword
from .totem import Totem
from .tropical_fish import TropicalFish
from .turtle_shell import TurtleShell
from .warped_fungus_on_a_stick import WarpedFungusOnAStick
from .wheat import Wheat
from .written_book import WrittenBook

comptime VanillaItems = ItemSet[
    AmethystShard,
    Apple,
    Arrow,
    Axe,
    BakedPotato,
    BannerPattern,
    Beef,
    Beetroot,
    BeetrootSoup,
    BlazePowder,
    BlazeRod,
    Bone,
    BoneMeal,
    Book,
    BookAndQuill,
    Boots,
    BottleOfEnchanting,
    Bow,
    Bowl,
    Bread,
    Brick,
    Bucket,
    CarrotOnAStick,
    Charcoal,
    Chestplate,
    Chicken,
    ClayBall,
    Clock,
    Coal,
    Cod,
    Compass,
    Cookie,
    CopperIngot,
    CopperNugget,
    Crossbow,
    Diamond,
    DiscFragment,
    DragonBreath,
    DriedKelp,
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
    FireworkStar,
    Flint,
    FlintAndSteel,
    GhastTear,
    GlassBottle,
    GlisteringMelonSlice,
    GlowstoneDust,
    GoatHorn,
    GoldIngot,
    GoldNugget,
    GoldenApple,
    GoldenCarrot,
    Gunpowder,
    HeartOfTheSea,
    Helmet,
    Hoe,
    HoneyBottle,
    Honeycomb,
    InkSac,
    IronIngot,
    IronNugget,
    LapisLazuli,
    Leather,
    Leggings,
    LingeringPotion,
    MagmaCream,
    MelonSlice,
    MushroomStew,
    MusicDisc,
    Mutton,
    NautilusShell,
    NetherBrick,
    NetherQuartz,
    NetherStar,
    NetheriteIngot,
    NetheriteScrap,
    Paper,
    PhantomMembrane,
    Pickaxe,
    PoisonousPotato,
    PoppedChorusFruit,
    Porkchop,
    Potion,
    PotterySherd,
    PrismarineCrystals,
    PrismarineShard,
    Pufferfish,
    PumpkinPie,
    Rabbit,
    RabbitFoot,
    RabbitHide,
    RabbitStew,
    RawCopper,
    RawGold,
    RawIron,
    RecoveryCompass,
    ResinBrick,
    RottenFlesh,
    Salmon,
    Scute,
    Shears,
    Shovel,
    ShulkerShell,
    Slimeball,
    SmithingTemplate,
    Snowball,
    SpiderEye,
    SplashPotion,
    Spyglass,
    Stick,
    Sugar,
    SuspiciousStew,
    Sword,
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
    Amethyst,
    AncientDebris,
    Andesite,
    Anvil,
    Bamboo,
    BambooBlock,
    BambooMosaic,
    Banner,
    Barrel,
    Barrier,
    Basalt,
    Beacon,
    Bed,
    Bedrock,
    BeetrootSeeds,
    Blackstone,
    BlastFurnace,
    BlueIce,
    BoneBlock,
    Bookshelf,
    BrewingStand,
    Bricks,
    Cactus,
    Cake,
    Calcite,
    Campfire,
    Candle,
    Carpet,
    Carrot,
    Chest,
    ChiseledQuartz,
    Cinnabar,
    CinnabarBricks,
    Clay,
    CoalBlock,
    CoalOre,
    Cobblestone,
    Cobweb,
    CocoaBean,
    Composter,
    Concrete,
    ConcretePowder,
    Copper,
    CopperBars,
    CopperChain,
    CopperDoor,
    CopperGolemStatue,
    CopperGrate,
    CopperLantern,
    CopperOre,
    CopperTorch,
    CopperTrapdoor,
    Coral,
    CoralBlock,
    CraftingTable,
    DeadBush,
    DecoratedPot,
    Deepslate,
    DeepslateBricks,
    DeepslateTiles,
    DiamondBlock,
    DiamondOre,
    Diorite,
    Dirt,
    DirtPath,
    DoubleFlower,
    DoubleTallGrass,
    DragonEgg,
    DriedKelpBlock,
    Dripstone,
    EmeraldBlock,
    EmeraldOre,
    EnchantingTable,
    EndBricks,
    EndPortalFrame,
    EndRod,
    EndStone,
    EnderChest,
    Farmland,
    Fern,
    FletchingTable,
    Flower,
    Froglight,
    Furnace,
    GlassPane,
    Glowstone,
    Gold,
    GoldOre,
    Granite,
    Grass,
    Gravel,
    Grindstone,
    HayBale,
    HoneycombBlock,
    Hopper,
    Ice,
    InfestedCobblestone,
    InfestedDeepslate,
    InfestedStone,
    InfestedStoneBricks,
    InvisibleBedrock,
    Iron,
    IronBars,
    IronChain,
    IronOre,
    ItemFrame,
    Jukebox,
    Kelp,
    Ladder,
    Lantern,
    Lapis,
    LapisOre,
    Leaves,
    Lectern,
    Lever,
    Light,
    LilyPad,
    LitPumpkin,
    Log,
    Loom,
    Stone,
    Terracotta,
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
