"""Registration of the vanilla blocks, ported from Dragonfly
`server/block/register.go`.

Go registers each block value with `world.RegisterBlock` from `init`. Here
each type lists its values in `all_states`, and `VanillaBlocks` lists the
types; `vanilla_block_registry` builds the registry a server uses.
"""

from ..world.block_registry import BasicBlockRegistry
from ..world.block_set import BlockSet
from .air import Air
from .amethyst import Amethyst
from .ancient_debris import AncientDebris
from .anvil import Anvil
from .bamboo import Bamboo
from .bamboo_block import BambooBlock
from .bamboo_mosaic import BambooMosaic
from .bamboo_sapling import BambooSapling
from .banner import Banner
from .barrel import Barrel
from .barrier import Barrier
from .basalt import Basalt
from .beacon import Beacon
from .bed import Bed
from .bedrock import Bedrock
from .beetroot_seeds import BeetrootSeeds
from .blackstone import Blackstone
from .blast_furnace import BlastFurnace
from .blue_ice import BlueIce
from .bone import Bone
from .bookshelf import Bookshelf
from .break_info import BreakInfo, Breakable
from .brewing_stand import BrewingStand
from .bricks import Bricks
from .cactus import Cactus
from .cake import Cake
from .calcite import Calcite
from .campfire import Campfire
from .candle import Candle
from .carpet import Carpet
from .carrot import Carrot
from .chest import Chest
from .cinnabar import Cinnabar
from .cinnabar_bricks import CinnabarBricks
from .clay import Clay
from .coal import Coal
from .coal_ore import CoalOre
from .cobblestone import Cobblestone
from .cobweb import Cobweb
from .cocoa_bean import CocoaBean
from .composter import Composter
from .concrete import Concrete
from .concrete_powder import ConcretePowder
from .copper import Copper
from .copper_bars import CopperBars
from .copper_chain import CopperChain
from .copper_door import CopperDoor
from .copper_golem_statue import CopperGolemStatue
from .copper_grate import CopperGrate
from .copper_lantern import CopperLantern
from .copper_ore import CopperOre
from .copper_torch import CopperTorch
from .copper_trapdoor import CopperTrapdoor
from .coral import Coral
from .coral_block import CoralBlock
from .crafting_table import CraftingTable
from .deadbush import DeadBush
from .decorated_pot import DecoratedPot
from .deepslate import Deepslate
from .deepslate_bricks import DeepslateBricks
from .deepslate_tiles import DeepslateTiles
from .diamond import Diamond
from .diamond_ore import DiamondOre
from .dirt import Dirt
from .dirt_path import DirtPath
from .double_flower import DoubleFlower
from .double_tall_grass import DoubleTallGrass
from .dragon_egg import DragonEgg
from .dried_kelp import DriedKelp
from .dripstone import Dripstone
from .emerald import Emerald
from .emerald_ore import EmeraldOre
from .enchanting_table import EnchantingTable
from .end_bricks import EndBricks
from .end_portal import EndPortal
from .end_portal_frame import EndPortalFrame
from .end_rod import EndRod
from .end_stone import EndStone
from .ender_chest import EnderChest
from .farmland import Farmland
from .fern import Fern
from .fire import Fire
from .fletching_table import FletchingTable
from .flower import Flower
from .froglight import Froglight
from .furnace import Furnace
from .glass import Glass
from .glass_pane import GlassPane
from .glazed_terracotta import GlazedTerracotta
from .glowstone import Glowstone
from .gold import Gold
from .gold_ore import GoldOre
from .grass import Grass
from .gravel import Gravel
from .grindstone import Grindstone
from .hay_bale import HayBale
from .honeycomb import Honeycomb
from .hopper import Hopper
from .ice import Ice
from .infested_cobblestone import InfestedCobblestone
from .infested_deepslate import InfestedDeepslate
from .infested_stone import InfestedStone
from .infested_stone_bricks import InfestedStoneBricks
from .invisible_bedrock import InvisibleBedrock
from .iron import Iron
from .iron_bars import IronBars
from .iron_chain import IronChain
from .iron_ore import IronOre
from .item_frame import ItemFrame
from .jukebox import Jukebox
from .kelp import Kelp
from .ladder import Ladder
from .lantern import Lantern
from .lapis import Lapis
from .lapis_ore import LapisOre
from .lava import Lava
from .leaves import Leaves
from .lectern import Lectern
from .lever import Lever
from .light import Light
from .lily_pad import LilyPad
from .lit_pumpkin import LitPumpkin
from .log import Log
from .loom import Loom
from .magma import Magma
from .melon import Melon
from .melon_seeds import MelonSeeds
from .moss_carpet import MossCarpet
from .mud import Mud
from .mud_bricks import MudBricks
from .muddy_mangrove_roots import MuddyMangroveRoots
from .mycelium import Mycelium
from .nether_brick_fence import NetherBrickFence
from .nether_bricks import NetherBricks
from .nether_gold_ore import NetherGoldOre
from .nether_sprouts import NetherSprouts
from .nether_wart import NetherWart
from .nether_wart_block import NetherWartBlock
from .netherite import Netherite
from .netherrack import Netherrack
from .note import Note
from .obsidian import Obsidian
from .packed_ice import PackedIce
from .packed_mud import PackedMud
from .pink_petals import PinkPetals
from .planks import Planks
from .podzol import Podzol
from .polished_blackstone_brick import PolishedBlackstoneBrick
from .polished_cinnabar import PolishedCinnabar
from .polished_sulfur import PolishedSulfur
from .polished_tuff import PolishedTuff
from .portal import Portal
from .potato import Potato
from .prismarine import Prismarine
from .pumpkin import Pumpkin
from .pumpkin_seeds import PumpkinSeeds
from .purpur import Purpur, PurpurPillar
from .quartz import ChiseledQuartz, Quartz, QuartzPillar
from .quartz_bricks import QuartzBricks
from .quartz_ore import NetherQuartzOre
from .raw_copper import RawCopper
from .raw_gold import RawGold
from .raw_iron import RawIron
from .red_shrub import RedShrub
from .redstone_block import RedstoneBlock
from .redstone_ore import RedstoneOre
from .redstone_torch import RedstoneTorch
from .redstone_wire import RedstoneWire
from .reinforced_deepslate import ReinforcedDeepslate
from .resin import Resin
from .resin_bricks import ResinBricks
from .sand import Sand
from .sandstone import Sandstone
from .sapling import Sapling
from .sea_lantern import SeaLantern
from .sea_pickle import SeaPickle
from .shelf_mushroom import ShelfMushroom
from .short_grass import ShortGrass
from .shroomlight import Shroomlight
from .shulker_box import ShulkerBox
from .sign import Sign
from .skull import Skull
from .slab import Slab
from .slime import Slime
from .smithing_table import SmithingTable
from .smoker import Smoker
from .smooth_basalt import SmoothBasalt
from .snow import Snow
from .soul_sand import SoulSand
from .soul_soil import SoulSoil
from .sponge import Sponge
from .spore_blossom import SporeBlossom
from .stained_glass import StainedGlass
from .stained_glass_pane import StainedGlassPane
from .stained_terracotta import StainedTerracotta
from .stairs import Stairs
from .stone import Andesite, Diorite, Granite, Stone
from .stone_bricks import StoneBricks
from .stonecutter import Stonecutter
from .straw_bed import StrawBed
from .string import StringBlock
from .sugar_cane import SugarCane
from .sulfur import Sulfur
from .sulfur_bricks import SulfurBricks
from .terracotta import Terracotta
from .tinted_glass import TintedGlass
from .tnt import TNT
from .torch import Torch
from .tuff import Tuff
from .tuff_bricks import TuffBricks
from .vine import Vines
from .wall import Wall
from .water import Water
from .wheat_seeds import WheatSeeds
from .wood import Wood
from .wood_door import WoodDoor
from .wood_fence import WoodFence
from .wood_fence_gate import WoodFenceGate
from .wood_trapdoor import WoodTrapdoor
from .wool import Wool

comptime VanillaBlocks = BlockSet[
    Air,
    Amethyst,
    AncientDebris,
    Andesite,
    Anvil,
    Bamboo,
    BambooBlock,
    BambooMosaic,
    BambooSapling,
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
    Bone,
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
    Coal,
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
    Diamond,
    DiamondOre,
    Diorite,
    Dirt,
    DirtPath,
    DoubleFlower,
    DoubleTallGrass,
    DragonEgg,
    DriedKelp,
    Dripstone,
    Emerald,
    EmeraldOre,
    EnchantingTable,
    EndBricks,
    EndPortal,
    EndPortalFrame,
    EndRod,
    EndStone,
    EnderChest,
    Farmland,
    Fern,
    Fire,
    FletchingTable,
    Flower,
    Froglight,
    Furnace,
    Glass,
    GlassPane,
    GlazedTerracotta,
    Glowstone,
    Gold,
    GoldOre,
    Granite,
    Grass,
    Gravel,
    Grindstone,
    HayBale,
    Honeycomb,
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
    Lava,
    Leaves,
    Lectern,
    Lever,
    Light,
    LilyPad,
    LitPumpkin,
    Log,
    Loom,
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
    Portal,
    Potato,
    Prismarine,
    Pumpkin,
    PumpkinSeeds,
    Purpur,
    PurpurPillar,
    Quartz,
    QuartzBricks,
    QuartzPillar,
    RawCopper,
    RawGold,
    RawIron,
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
    Terracotta,
    TintedGlass,
    Torch,
    Tuff,
    TuffBricks,
    Vines,
    Wall,
    Water,
    WheatSeeds,
    Wood,
    WoodDoor,
    WoodFence,
    WoodFenceGate,
    WoodTrapdoor,
    Wool,
]
"""Every block type Ignis implements, sorted by name."""

comptime BLOCK_STATES_PATH = "resources/block_states.nbt"
"""Where `block_states.nbt` lives, relative to the repository root."""


def vanilla_block_registry(
    path: String = BLOCK_STATES_PATH,
) raises -> BasicBlockRegistry:
    """Builds the finalized vanilla registry (Go `DefaultBlockRegistry`
    after `Finalize`).

    Args:
        path: The path of `block_states.nbt`.

    Returns:
        The registry.

    Raises:
        If the file cannot be read or a block does not match a state.
    """
    var br = BasicBlockRegistry.load(path)
    VanillaBlocks.register_all(br)
    br.finalize()
    return br^


def break_info(kind: UInt64, hash: UInt64) -> Optional[BreakInfo]:
    """Returns the break info of a block of any vanilla type (Go
    `b.(Breakable).BreakInfo()`).

    Args:
        kind: The `BASE_HASH` of the block's type.
        hash: The block's state hash.

    Returns:
        The break info, or None if the type is unknown or not `Breakable`.
    """
    comptime for i in range(len(VanillaBlocks.Ts)):
        comptime T = VanillaBlocks.Ts[i]
        comptime if conforms_to(T, Breakable):
            if kind == T.BASE_HASH:
                return _break_info[T](T.from_hash(hash))
    return None


def _break_info[T: Breakable](b: T) -> BreakInfo:
    return b.break_info()
