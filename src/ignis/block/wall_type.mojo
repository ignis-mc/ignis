"""The blocks walls are made of, ported from Dragonfly
`server/block/wall_type.go`.
"""

from std.os import abort

from .blackstone import Blackstone
from .blackstone_type import BlackstoneType
from .bricks import Bricks
from .cinnabar import Cinnabar
from .cinnabar_bricks import CinnabarBricks
from .cobblestone import Cobblestone
from .deepslate import Deepslate
from .deepslate_bricks import DeepslateBricks
from .deepslate_tiles import DeepslateTiles
from .deepslate_type import DeepslateType
from .end_bricks import EndBricks
from .hash import AnyBlock
from .mud_bricks import MudBricks
from .nether_bricks import NetherBricks
from .nether_bricks_type import NetherBricksType
from .polished_blackstone_brick import PolishedBlackstoneBrick
from .polished_cinnabar import PolishedCinnabar
from .polished_sulfur import PolishedSulfur
from .polished_tuff import PolishedTuff
from .prismarine import Prismarine
from .prismarine_type import PrismarineType
from .resin_bricks import ResinBricks
from .sandstone import Sandstone
from .sandstone_type import SandstoneType
from .stone import Andesite, Diorite, Granite
from .stone_bricks import StoneBricks
from .stone_bricks_type import StoneBricksType
from .sulfur import Sulfur
from .sulfur_bricks import SulfurBricks
from .tuff import Tuff
from .tuff_bricks import TuffBricks


def encode_wall_block(block: AnyBlock) -> String:
    """Returns the name walls of the block encode with, without the `_wall`
    suffix (Go `encodeWallBlock`). Aborts for blocks that have no wall, as Go
    panics."""
    if case .Some(b) = block.get[Andesite]():
        if not b.polished:
            return "andesite"
    if case .Some(b) = block.get[Blackstone]():
        if b.type == BlackstoneType.NORMAL:
            return "blackstone"
        if b.type == BlackstoneType.POLISHED:
            return "polished_blackstone"
    if block.is_a[Bricks]():
        return "brick"
    if case .Some(b) = block.get[Cinnabar]():
        if not b.chiseled:
            return "cinnabar"
    if block.is_a[CinnabarBricks]():
        return "cinnabar_brick"
    if case .Some(b) = block.get[Cobblestone]():
        return "mossy_cobblestone" if b.mossy else "cobblestone"
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
        if not b.polished:
            return "diorite"
    if block.is_a[EndBricks]():
        return "end_stone_brick"
    if case .Some(b) = block.get[Granite]():
        if not b.polished:
            return "granite"
    if block.is_a[MudBricks]():
        return "mud_brick"
    if case .Some(b) = block.get[NetherBricks]():
        if b.type == NetherBricksType.NORMAL:
            return "nether_brick"
        if b.type == NetherBricksType.RED:
            return "red_nether_brick"
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
    if block.is_a[ResinBricks]():
        return "resin_brick"
    if case .Some(b) = block.get[Sandstone]():
        if b.type == SandstoneType.NORMAL:
            return "red_sandstone" if b.red else "sandstone"
    if case .Some(b) = block.get[StoneBricks]():
        if b.type == StoneBricksType.NORMAL:
            return "stone_brick"
        if b.type == StoneBricksType.MOSSY:
            return "mossy_stone_brick"
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
    abort(t"invalid block used for wall: {block}")


def wall_blocks() -> List[AnyBlock]:
    """Returns every block a wall can be made of (Go `WallBlocks`)."""
    return [
        AnyBlock(Andesite()),
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
        AnyBlock(Diorite()),
        AnyBlock(EndBricks()),
        AnyBlock(Granite()),
        AnyBlock(MudBricks()),
        AnyBlock(NetherBricks(type=NetherBricksType.RED)),
        AnyBlock(NetherBricks()),
        AnyBlock(PolishedBlackstoneBrick()),
        AnyBlock(PolishedCinnabar()),
        AnyBlock(PolishedSulfur()),
        AnyBlock(PolishedTuff()),
        AnyBlock(Prismarine()),
        AnyBlock(ResinBricks()),
        AnyBlock(Sandstone(red=True)),
        AnyBlock(Sandstone()),
        AnyBlock(StoneBricks(type=StoneBricksType.MOSSY)),
        AnyBlock(StoneBricks()),
        AnyBlock(Sulfur()),
        AnyBlock(SulfurBricks()),
        AnyBlock(Tuff()),
        AnyBlock(TuffBricks()),
    ]
