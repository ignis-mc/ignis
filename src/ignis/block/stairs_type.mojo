"""The blocks stairs are made of, ported from Dragonfly
`server/block/stairs_type.go`.

Dragonfly swaps the nether brick stairs: its `NetherBricks{Type:
RedNetherBricks()}` stairs encode as `nether_brick_stairs` and the plain ones
as `red_nether_brick_stairs`. Here each encodes as its own stairs; the states
on the wire are the same set, only which `Stairs` value maps to which
differs.
"""

from std.os import abort

from ..item.colour import colours
from .bamboo_mosaic import BambooMosaic
from .blackstone import Blackstone
from .blackstone_type import BlackstoneType
from .bricks import Bricks
from .cinnabar import Cinnabar
from .cinnabar_bricks import CinnabarBricks
from .cobblestone import Cobblestone
from .concrete import Concrete
from .copper import Copper
from .copper_type import CopperType
from .deepslate import Deepslate
from .deepslate_bricks import DeepslateBricks
from .deepslate_tiles import DeepslateTiles
from .deepslate_type import DeepslateType
from .end_bricks import EndBricks
from .hash import AnyBlock
from .mud_bricks import MudBricks
from .nether_bricks import NetherBricks
from .nether_bricks_type import NetherBricksType
from .oxidation_type import OxidationType, oxidation_types
from .planks import Planks
from .polished_blackstone_brick import PolishedBlackstoneBrick
from .polished_cinnabar import PolishedCinnabar
from .polished_sulfur import PolishedSulfur
from .polished_tuff import PolishedTuff
from .prismarine import Prismarine
from .prismarine_type import PrismarineType, prismarine_types
from .purpur import Purpur
from .quartz import Quartz
from .resin_bricks import ResinBricks
from .sandstone import Sandstone
from .sandstone_type import SandstoneType, sandstone_types
from .stone import Andesite, Diorite, Granite, Stone
from .stone_bricks import StoneBricks
from .stone_bricks_type import StoneBricksType
from .sulfur import Sulfur
from .sulfur_bricks import SulfurBricks
from .tuff import Tuff
from .tuff_bricks import TuffBricks
from .wood_type import wood_types
from .wool import Wool


def encode_stairs_block(block: AnyBlock) -> String:
    """Returns the name stairs of the block encode with, without the
    `_stairs` suffix (Go `encodeStairsBlock`). Aborts for blocks that have no
    stairs, as Go panics."""
    if case .Some(b) = block.get[Andesite]():
        return "polished_andesite" if b.polished else "andesite"
    if case .Some(b) = block.get[Blackstone]():
        if b.type == BlackstoneType.NORMAL:
            return "blackstone"
        if b.type == BlackstoneType.POLISHED:
            return "polished_blackstone"
    if block.is_a[BambooMosaic]():
        return "bamboo_mosaic"
    if block.is_a[Bricks]():
        return "brick"
    if case .Some(b) = block.get[Cinnabar]():
        if not b.chiseled:
            return "cinnabar"
    if block.is_a[CinnabarBricks]():
        return "cinnabar_brick"
    if case .Some(b) = block.get[Cobblestone]():
        return "mossy_cobblestone" if b.mossy else "stone"
    if case .Some(b) = block.get[Concrete]():
        return String(t"{b.colour}_concrete")
    if case .Some(b) = block.get[Copper]():
        if b.type == CopperType.CUT:
            var name = String("cut_copper")
            if b.oxidation != OxidationType.UNOXIDISED:
                name = String(t"{b.oxidation}_{name}")
            if b.waxed:
                name = "waxed_" + name
            return name^
    if case .Some(b) = block.get[Deepslate]():
        if b.type == DeepslateType.COBBLED:
            return "cobbled_deepslate"
        if b.type == DeepslateType.POLISHED:
            return "polished_deepslate"
    if case .Some(b) = block.get[DeepslateBricks]():
        if not b.cracked:
            return "deepslate_brick"
    if case .Some(b) = block.get[DeepslateTiles]():
        if not b.cracked:
            return "deepslate_tile"
    if case .Some(b) = block.get[Diorite]():
        return "polished_diorite" if b.polished else "diorite"
    if block.is_a[EndBricks]():
        return "end_brick"
    if case .Some(b) = block.get[Granite]():
        return "polished_granite" if b.polished else "granite"
    if block.is_a[MudBricks]():
        return "mud_brick"
    if case .Some(b) = block.get[NetherBricks]():
        # Go returns these the other way round (see the module docstring).
        if b.type == NetherBricksType.RED:
            return "red_nether_brick"
        return "nether_brick"
    if case .Some(b) = block.get[Planks]():
        return String(b.wood)
    if case .Some(b) = block.get[PolishedBlackstoneBrick]():
        if not b.cracked:
            return "polished_blackstone_brick"
    if block.is_a[PolishedCinnabar]():
        return "polished_cinnabar"
    if block.is_a[PolishedSulfur]():
        return "polished_sulfur"
    if block.is_a[PolishedTuff]():
        return "polished_tuff"
    if case .Some(b) = block.get[Prismarine]():
        if b.type == PrismarineType.NORMAL:
            return "prismarine"
        if b.type == PrismarineType.DARK:
            return "dark_prismarine"
        return "prismarine_bricks"
    if block.is_a[Purpur]():
        return "purpur"
    if case .Some(b) = block.get[Quartz]():
        return "smooth_quartz" if b.smooth else "quartz"
    if block.is_a[ResinBricks]():
        return "resin_brick"
    if case .Some(b) = block.get[Sandstone]():
        var red = "red_" if b.red else ""
        if b.type == SandstoneType.NORMAL:
            return String(t"{red}sandstone")
        if b.type == SandstoneType.SMOOTH:
            return String(t"smooth_{red}sandstone")
    if case .Some(b) = block.get[Stone]():
        if not b.smooth:
            return "normal_stone"
    if case .Some(b) = block.get[StoneBricks]():
        if b.type == StoneBricksType.MOSSY:
            return "mossy_stone_brick"
        return "stone_brick"
    if case .Some(b) = block.get[Sulfur]():
        if not b.chiseled:
            return "sulfur"
    if block.is_a[SulfurBricks]():
        return "sulfur_brick"
    if case .Some(b) = block.get[Tuff]():
        if not b.chiseled:
            return "tuff"
    if case .Some(b) = block.get[TuffBricks]():
        if not b.chiseled:
            return "tuff_brick"
    if case .Some(b) = block.get[Wool]():
        return String(t"{b.colour}_wool")
    abort(t"invalid block used for stairs: {block}")


def stairs_blocks() -> List[AnyBlock]:
    """Returns every block stairs can be made of (Go `StairsBlocks`)."""
    var b: List[AnyBlock] = [
        AnyBlock(Andesite(polished=True)),
        AnyBlock(Andesite()),
        AnyBlock(BambooMosaic()),
        AnyBlock(Blackstone(type=BlackstoneType.POLISHED)),
        AnyBlock(Blackstone()),
        AnyBlock(Bricks()),
        AnyBlock(Cinnabar()),
        AnyBlock(CinnabarBricks()),
        AnyBlock(Cobblestone(mossy=True)),
        AnyBlock(Cobblestone()),
        AnyBlock(DeepslateBricks()),
        AnyBlock(DeepslateTiles()),
        AnyBlock(Deepslate(type=DeepslateType.COBBLED)),
        AnyBlock(Deepslate(type=DeepslateType.POLISHED)),
        AnyBlock(Diorite(polished=True)),
        AnyBlock(Diorite()),
        AnyBlock(EndBricks()),
        AnyBlock(Granite(polished=True)),
        AnyBlock(Granite()),
        AnyBlock(MudBricks()),
        AnyBlock(NetherBricks(type=NetherBricksType.RED)),
        AnyBlock(NetherBricks()),
        AnyBlock(PolishedBlackstoneBrick()),
        AnyBlock(PolishedCinnabar()),
        AnyBlock(PolishedSulfur()),
        AnyBlock(PolishedTuff()),
        AnyBlock(Purpur()),
        AnyBlock(Quartz(smooth=True)),
        AnyBlock(Quartz()),
        AnyBlock(ResinBricks()),
        AnyBlock(StoneBricks(type=StoneBricksType.MOSSY)),
        AnyBlock(StoneBricks()),
        AnyBlock(Stone()),
        AnyBlock(Sulfur()),
        AnyBlock(SulfurBricks()),
        AnyBlock(Tuff()),
        AnyBlock(TuffBricks()),
    ]
    for p in prismarine_types():
        b.append(AnyBlock(Prismarine(type=p)))
    for s in sandstone_types():
        if s != SandstoneType.CUT and s != SandstoneType.CHISELED:
            b.append(AnyBlock(Sandstone(type=s)))
            b.append(AnyBlock(Sandstone(type=s, red=True)))
    for w in wood_types():
        b.append(AnyBlock(Planks(wood=w)))
    for o in oxidation_types():
        b.append(AnyBlock(Copper(type=CopperType.CUT, oxidation=o)))
        b.append(AnyBlock(Copper(type=CopperType.CUT, oxidation=o, waxed=True)))
    for c in colours():
        b.append(AnyBlock(Concrete(colour=c)))
        b.append(AnyBlock(Wool(colour=c)))
    return b^
