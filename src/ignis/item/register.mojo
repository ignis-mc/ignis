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
from ..block.grass import Grass
from ..block.stone import Stone
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
from .item_set import ItemSet

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

comptime VanillaBlockItems = ItemSet[Air, Bedrock, Dirt, Grass, Stone]
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
