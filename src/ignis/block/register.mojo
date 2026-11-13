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
from .bamboo_block import BambooBlock
from .bamboo_mosaic import BambooMosaic
from .barrier import Barrier
from .basalt import Basalt
from .beacon import Beacon
from .bedrock import Bedrock
from .blackstone import Blackstone
from .blue_ice import BlueIce
from .bone import Bone
from .bookshelf import Bookshelf
from .break_info import BreakInfo, Breakable
from .bricks import Bricks
from .calcite import Calcite
from .carpet import Carpet
from .cinnabar import Cinnabar
from .cinnabar_bricks import CinnabarBricks
from .clay import Clay
from .coal import Coal
from .coal_ore import CoalOre
from .cobblestone import Cobblestone
from .cobweb import Cobweb
from .concrete import Concrete
from .concrete_powder import ConcretePowder
from .copper_ore import CopperOre
from .coral_block import CoralBlock
from .crafting_table import CraftingTable
from .deepslate import Deepslate
from .deepslate_bricks import DeepslateBricks
from .deepslate_tiles import DeepslateTiles
from .diamond import Diamond
from .diamond_ore import DiamondOre
from .dirt import Dirt
from .dirt_path import DirtPath
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
from .farmland import Farmland
from .fletching_table import FletchingTable
from .froglight import Froglight
from .glass import Glass
from .glass_pane import GlassPane
from .glazed_terracotta import GlazedTerracotta
from .glowstone import Glowstone
from .gold import Gold
from .gold_ore import GoldOre
from .grass import Grass
from .gravel import Gravel
from .hay_bale import HayBale
from .honeycomb import Honeycomb
from .ice import Ice
from .infested_cobblestone import InfestedCobblestone
from .infested_deepslate import InfestedDeepslate
from .infested_stone import InfestedStone
from .infested_stone_bricks import InfestedStoneBricks
from .invisible_bedrock import InvisibleBedrock
from .iron import Iron
from .iron_ore import IronOre
from .jukebox import Jukebox
from .lapis import Lapis
from .lapis_ore import LapisOre
from .leaves import Leaves
from .light import Light
from .log import Log
from .magma import Magma
from .melon import Melon
from .moss_carpet import MossCarpet
from .mud import Mud
from .mud_bricks import MudBricks
from .muddy_mangrove_roots import MuddyMangroveRoots
from .mycelium import Mycelium
from .nether_bricks import NetherBricks
from .nether_gold_ore import NetherGoldOre
from .nether_wart_block import NetherWartBlock
from .netherite import Netherite
from .netherrack import Netherrack
from .note import Note
from .obsidian import Obsidian
from .packed_ice import PackedIce
from .packed_mud import PackedMud
from .planks import Planks
from .podzol import Podzol
from .polished_blackstone_brick import PolishedBlackstoneBrick
from .polished_cinnabar import PolishedCinnabar
from .polished_sulfur import PolishedSulfur
from .polished_tuff import PolishedTuff
from .portal import Portal
from .prismarine import Prismarine
from .purpur import Purpur, PurpurPillar
from .quartz import ChiseledQuartz, Quartz, QuartzPillar
from .quartz_bricks import QuartzBricks
from .quartz_ore import NetherQuartzOre
from .raw_copper import RawCopper
from .raw_gold import RawGold
from .raw_iron import RawIron
from .redstone_block import RedstoneBlock
from .redstone_ore import RedstoneOre
from .reinforced_deepslate import ReinforcedDeepslate
from .resin import Resin
from .resin_bricks import ResinBricks
from .sand import Sand
from .sandstone import Sandstone
from .sea_lantern import SeaLantern
from .shroomlight import Shroomlight
from .slime import Slime
from .smithing_table import SmithingTable
from .smooth_basalt import SmoothBasalt
from .snow import Snow
from .soul_sand import SoulSand
from .soul_soil import SoulSoil
from .sponge import Sponge
from .spore_blossom import SporeBlossom
from .stained_glass import StainedGlass
from .stained_glass_pane import StainedGlassPane
from .stained_terracotta import StainedTerracotta
from .stone import Andesite, Diorite, Granite, Stone
from .stone_bricks import StoneBricks
from .sulfur import Sulfur
from .sulfur_bricks import SulfurBricks
from .terracotta import Terracotta
from .tinted_glass import TintedGlass
from .tnt import TNT
from .tuff import Tuff
from .tuff_bricks import TuffBricks
from .wood import Wood
from .wool import Wool

comptime VanillaBlocks = BlockSet[
    Air,
    Amethyst,
    AncientDebris,
    Andesite,
    BambooBlock,
    BambooMosaic,
    Barrier,
    Basalt,
    Beacon,
    Bedrock,
    Blackstone,
    BlueIce,
    Bone,
    Bookshelf,
    Bricks,
    Calcite,
    Carpet,
    ChiseledQuartz,
    Cinnabar,
    CinnabarBricks,
    Clay,
    Coal,
    CoalOre,
    Cobblestone,
    Cobweb,
    Concrete,
    ConcretePowder,
    CopperOre,
    CoralBlock,
    CraftingTable,
    Deepslate,
    DeepslateBricks,
    DeepslateTiles,
    Diamond,
    DiamondOre,
    Diorite,
    Dirt,
    DirtPath,
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
    Farmland,
    FletchingTable,
    Froglight,
    Glass,
    GlassPane,
    GlazedTerracotta,
    Glowstone,
    Gold,
    GoldOre,
    Granite,
    Grass,
    Gravel,
    HayBale,
    Honeycomb,
    Ice,
    InfestedCobblestone,
    InfestedDeepslate,
    InfestedStone,
    InfestedStoneBricks,
    InvisibleBedrock,
    Iron,
    IronOre,
    Jukebox,
    Lapis,
    LapisOre,
    Leaves,
    Light,
    Log,
    Magma,
    Melon,
    MossCarpet,
    Mud,
    MudBricks,
    MuddyMangroveRoots,
    Mycelium,
    NetherBricks,
    NetherGoldOre,
    NetherQuartzOre,
    NetherWartBlock,
    Netherite,
    Netherrack,
    Note,
    Obsidian,
    PackedIce,
    PackedMud,
    Planks,
    Podzol,
    PolishedBlackstoneBrick,
    PolishedCinnabar,
    PolishedSulfur,
    PolishedTuff,
    Portal,
    Prismarine,
    Purpur,
    PurpurPillar,
    Quartz,
    QuartzBricks,
    QuartzPillar,
    RawCopper,
    RawGold,
    RawIron,
    RedstoneBlock,
    RedstoneOre,
    ReinforcedDeepslate,
    Resin,
    ResinBricks,
    Sand,
    Sandstone,
    SeaLantern,
    Shroomlight,
    Slime,
    SmithingTable,
    SmoothBasalt,
    Snow,
    SoulSand,
    SoulSoil,
    Sponge,
    SporeBlossom,
    StainedGlass,
    StainedGlassPane,
    StainedTerracotta,
    Stone,
    StoneBricks,
    Sulfur,
    SulfurBricks,
    TNT,
    Terracotta,
    TintedGlass,
    Tuff,
    TuffBricks,
    Wood,
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
